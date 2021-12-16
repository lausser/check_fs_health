package Classes::Filesystem::Component::ResponseSubsystem;
our @ISA = qw(Monitoring::GLPlugin::Item);
use strict;
use Time::HiRes;
use File::stat;
use threads;

sub check_filesystem_type {
  my($self) = @_;
  $self->{path} = $self->opts->name;
  my $mounts = {};
  open(MTAB, "/etc/mtab");
  while (<MTAB>) {
    # rootfs / wslfs rw,noatime 0 0
    # none /dev tmpfs rw,noatime,mode=755 0 0
    my ($device, $fs, $type, $options) = split(/\s+/, $_, 4);
    $mounts->{$fs} = [$device, $type, $options];
  }
  close MTAB;
  foreach my $mountpoint (reverse sort { length($a) <=> length($b) } keys %{$mounts}) {
    #printf "mp %s\n", $mountpoint;
    if (rindex($self->opts->name, $mountpoint) == 0) {
      $self->{fstype} = $mounts->{$mountpoint}[1];
      $self->{device} = $mounts->{$mountpoint}[0];
      $self->{mountpoint} = $mountpoint;
      last;
    }
  }
  if (! $self->{fstype}) {
    $self->{fstype} = $mounts->{"/"}[1];
    $self->{device} = $mounts->{"/"}[0];
    $self->{mountpoint} = "/";
  }
}

sub init {
  my ($self) = @_;
  my $elapsed = 0;
  $self->check_filesystem_type();
  $self->set_thresholds(
      metric => "timeout",
      warning => $self->opts->timeout,
      critical => $self->opts->timeout,
  );
  my $thread = threads->create(
    sub {
      return $self->can_hang_init();
    }
  );
  while (1) {
    if ($thread->is_joinable()) {
      my $ret = $thread->join();
      $Monitoring::GLPlugin::plugin = $ret->{plugin};
      last;
    } elsif ($thread->is_running()) {
      if ($self->check_thresholds(
          metric => "timeout",
          value => $elapsed,
      )) {
        $thread->detach();
        $self->add_critical(sprintf "%s did not respond within %.2fs",
                $self->{path}, $elapsed);
        $self->add_perfdata(
            label => "operation_time_".$self->{path},
            value => $elapsed,
            uom => 's',
        );
        last;
      } else {
      }
    } elsif ($thread->is_detached()) {
      last;
    } else {
    }
    $elapsed += sleep(1);
    #if ($elapsed < $self->opts->timeout) {
    #}
  }
}


sub can_hang_init {
  my ($self) = @_;
  # add_* findet in $Monitoring::GLPlugin::plugin statt.
  # Da der Thread aber nur eine Kopie bearbeitet, muss diese am Ende
  # an den aufrufenden Prozess zurueckgegeben werden.
  $self->{plugin} = $Monitoring::GLPlugin::plugin;
  $self->{testfile} = $self->{path}."/".$self->opts->name2;
  if ($self->opts->fstype) {
    if ($self->opts->fstype ne $self->{fstype}) {
      $self->add_warning(sprintf "mountpoint %s of folder %s is of type %s, not %s",
          $self->{mountpoint}, $self->{path}, $self->{fstype}, $self->opts->fstype);
      return $self;
    }
  }
  if ($self->mode =~ /device::fs::write/) {
    if (-w $self->{path}) {
      my $fh = IO::File->new("> ".$self->{testfile});
      if (defined $fh) {
        printf $fh "this is a test and i hope i could write this to a file";
        $fh->close;
        unlink $self->{testfile};
        $self->add_ok(sprintf "successfull wrote a file in %s", $self->{path});
      } else {
        $self->add_critical(sprintf "write to %s failed", $self->{testfile});
      }
    } else {
      my $st = stat($self->{path});
      if (! defined $st and $self->{fstype} eq "nfs") {
        $self->add_critical(sprintf "cannot stat %s, stale file handle", $self->{path});
      } else {
        $self->add_critical(sprintf "no permission to write %s", $self->{testfile});
      }
    }
  } elsif ($self->mode =~ /device::fs::read/) {
    use filetest 'access';
    if (-r $self->{path}) {
      my $fh = IO::File->new($self->{testfile});
      if (defined $fh) {
        my @content = <$fh>;
        $fh->close;
        $self->add_ok(sprintf "successfull read from file %s", $self->{testfile});
      } else {
        $self->add_critical(sprintf "open file %s failed", $self->{testfile});
      }
    } else {
      $self->add_critical(sprintf "no permission to read %s", $self->{testfile});
    }
  } else {
    $self->no_such_mode();
  }
  return $self;
}

