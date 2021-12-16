package Classes::Filesystem;
our @ISA = qw(Classes::Device);
use strict;


sub init {
  my ($self) = @_;
  if ($self->mode =~ /device::fs::(read|write)/) {
    $self->analyze_and_check_fs_subsystem("Classes::Filesystem::Component::ResponseSubsystem");
  } elsif ($self->mode =~ /device::fs::free/) {
    $self->analyze_and_check_fs_subsystem("Classes::Filesystem::Component::SpaceSubsystem");
  } else {
    $self->no_such_mode();
  }
}

