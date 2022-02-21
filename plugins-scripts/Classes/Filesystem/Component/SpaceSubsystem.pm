package Classes::Filesystem::Component::SpaceSubsystem;
our @ISA = qw(Monitoring::GLPlugin::Item);
use strict;

sub init {
  my ($self) = @_;
  if (! $self->opts->can("units") || !$self->opts->units()) {
    $self->override_opt("units", "MB");
  }
  my @mounts = ();
  if ($^O eq "linux") {
    my $cmd = "df --output=fstype,source,size,avail,pcent,itotal,iused,ipcent,target";
    my @df = `$cmd 2>&1`;
    # Filesystem           1K-blocks     Avail Use% Inodes IUsed IUse% Mounted on
    # infini02oradatapsu02 157286400 105198144  34% 300000  4125    2% /infini02oradatapsu02
    foreach (@df) {
      my $fs = undef;
      if (/^Filesystem/) {
        next;
      } elsif (/^(.*?)\s+(.*?)\s+(\d+)\s+(\d+)\s+(\d+)%\s+(\d+)\s+(\-*\d+)\s+(\-)\s+(.*)/) {
        # wslfs
        $fs = {
            'fstype' => $1,
            'device' => $2,
            'size1k' => $3,
            'avail1k' => $4,
            'usedpct' => $5,
            'inodes' => 0,
            'iused' => 0,
            'iusedpct' => 0,
            'name' => $9,
        };
        $fs->{has_inodes} = $8 eq "-" ? 0 : 1;
      } elsif (/^(.*?)\s+(.*?)\s+(\d+)\s+(\d+)\s+(\d+)%\s+(\d+)\s+(\d+)\s+(\d+)%\s+(.*)/) {
        $fs = {
            'fstype' => $1,
            'device' => $2,
            'size1k' => $3,
            'avail1k' => $4,
            'usedpct' => $5,
            'inodes' => $6,
            'iused' => $7,
            'iusedpct' => $8,
            'name' => $9,
        };
        $fs->{has_inodes} = 1;
      }
      push(@mounts, $fs) if $fs;
    }
  } elsif ($^O eq "aix") {
    my $cmd = "df -k";
    my @df = `$cmd 2>&1`;
    # Filesystem    1024-blocks      Free %Used    Iused %Iused Mounted on
    # /dev/hd4          1376256    394448   72%    11572    12% /
    foreach (@df) {
      my $fs = undef;
      if (/^Filesystem/) {
        next;
      } elsif (/^(.*)\s+(\d+)\s+(\d+)\s+([\d\.]+)%\s+(\d+)\s+([\d\.]+)%\s+(.*)/) {
        $fs = {
            'device' => $1,
            'size1k' => $2,
            'avail1k' => $3,
            'usedpct' => $4,
            'iused' => $5,
            'iusedpct' => $6,
            'name' => $7,
        };
        $fs->{has_inodes} = 1;
      }
      push(@mounts, $fs) if $fs;
    }
  } else {
  }
  for my $fs (@mounts) {
    next if ! $self->filter_name($fs->{name}) and
        ! $self->filter_name($fs->{device});
    if ($self->filter_name($fs->{name})) {
      push(@{$self->{filesystems}},
          Classes::Filesystem::Component::SpaceSubsystem::Filesystem->new(%{$fs}));
    } elsif ($self->filter_name($fs->{device})) {
      push(@{$self->{devices}},
          Classes::Filesystem::Component::SpaceSubsystem::Filesystem->new(%{$fs}));
    }
  }
}

sub check {
  my ($self) = @_;
  if (! exists $self->{filesystems} and ! exists $self->{devices}) {
    $self->add_unknown("no filesystems found");
  } else {
    if (exists $self->{filesystems}) {
      foreach (@{$self->{filesystems}}) {
        $_->check();
      }
    }
  }
  if (exists $self->{devices}) {
    my $known_devices = {};
    @{$self->{devices}} = reverse grep {
      $known_devices->{$_->{device}}++;
      $known_devices->{$_->{device}} == 1;
    } reverse @{$self->{devices}};
    foreach (@{$self->{devices}}) {
      $_->check();
    }
  }
}

package Classes::Filesystem::Component::SpaceSubsystem::Filesystem;
our @ISA = qw(Monitoring::GLPlugin::TableItem);
use strict;

sub finish {
  my ($self) = @_;
  $self->{size} = 1024 * $self->{size1k};
  $self->{avail} = 1024 * $self->{avail1k};
  $self->{used} = $self->{size} - $self->{avail};
  $self->{freepct} = 100 - $self->{usedpct};
  my $has_bytes = {
      "K" => 1024,
      "KB" => 1024,
      "Kb" => 1024,
      "M" => 1024*1024,
      "MB" => 1024*1024,
      "Mb" => 1024*1024,
      "G" => 1024*1024*1024,
      "GB" => 1024*1024*1024,
      "Gb" => 1024*1024*1024,
      "T" => 1024*1024*1024*1024,
      "TB" => 1024*1024*1024*1024,
      "Tb" => 1024*1024*1024*1024,
  };
  if ($self->opts->units ne "%") {
    $self->{usize} = $self->{size} / $has_bytes->{$self->opts->units};
    $self->{uavail} = $self->{avail} / $has_bytes->{$self->opts->units};
    $self->{uused} = $self->{used} / $has_bytes->{$self->opts->units};
    $self->{ufree} = $self->{usize} - $self->{uused};
  } else {
    $self->{usize} = $self->{size} / $has_bytes->{"MB"};
    $self->{uavail} = $self->{avail} / $has_bytes->{"MB"};
    $self->{uused} = $self->{used} / $has_bytes->{"MB"};
    $self->{ufree} = $self->{usize} - $self->{uused};
  }
  $self->{ifreepct} = 100 - $self->{iusedpct};
  $self->{fstype} = exists $self->{fstype} ? $self->{fstype} : "unknown";
}

sub worst {
  my ($self, @states) = @_;
  return 2 if grep { $_ == 2 } @states;
  return 1 if grep { $_ == 1 } @states;
  return 3 if grep { $_ == 3 } @states;
  return 0;
}

sub check {
  my ($self) = @_;
  if ($self->opts->units eq "%") {
    $self->add_info(sprintf "%s %.2f %s",
        $self->{name}, $self->{ufree}, "MB");
  } else {
    $self->add_info(sprintf "%s %.2f %s",
        $self->{name}, $self->{ufree}, $self->opts->units);
  }
  if ($self->{has_inodes}) {
    $self->annotate_info(sprintf "%.2f%% inode=%d%%",
        $self->{freepct}, $self->{ifreepct});
    $self->set_thresholds(metric => $self->{name}."_inodes",
        warning => "5:",
        critical => "1:",
    );
  } else {
    $self->annotate_info(sprintf "%.2f%% inode=-",
        $self->{freepct});
  }
  my $inode_level = $self->check_thresholds(
      metric => $self->{name}."_inodes",
      value => $self->{ifreepct},
  );
  if ($self->opts->units eq "%") {
    $self->set_thresholds(metric => $self->{name},
        warning => "10:",
        critical => "5:",
    );
  } else {
    $self->set_thresholds(metric => $self->{name},
        warning => ($self->{usize} / 10).":",
        critical => ($self->{usize} / 20).":",
    );
  }
  my $space_level = $self->opts->units eq "%" ?
      $self->check_thresholds(
          metric => $self->{name},
          value => $self->{freepct},
      ) :
      $self->check_thresholds(
          metric => $self->{name},
          value => $self->{ufree},
      );
  if ($inode_level) {
    $self->annotate_info("inodes low, fstype ".$self->{fstype});
  }
  $self->add_message($self->worst($space_level, $inode_level));
  my ($warning, $critical) = $self->get_thresholds(metric => $self->{name});
  if ($self->opts->compat) {
    $warning = $1 if $warning =~ /^(.*):$/;
    $critical = $1 if $critical =~ /^(.*):$/;
    if ($self->opts->units eq "%") {
      $self->override_opt("units", "MB");
      $self->force_thresholds(metric => $self->{name},
          warning => $self->{usize} / 100 * (100 - $warning),
          critical => $self->{usize} / 100 * (100 - $critical),
      );
    } else {
      $self->force_thresholds(metric => $self->{name},
          warning => $self->{usize}  - $warning,
          critical => $self->{usize} - $critical,
      );
    }
    my ($warning, $critical) = $self->get_thresholds(metric => $self->{name});
    $self->add_perfdata(label => $self->{name},
        value => $self->{uused},
        uom => $self->opts->units,
        min => 0,
        max => $self->{usize},
        warning => $warning,
        critical => $critical,
    );
  } else {
    $self->add_perfdata(label => $self->{name},
        value => $self->{uavail},
        uom => $self->opts->units,
        min => 0,
        max => $self->{usize},
        warning => $warning,
        critical => $critical,
    );
  }
}
