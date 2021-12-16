package Classes::Device;
our @ISA = qw(Monitoring::GLPlugin);
use strict;

sub classify {
  my($self) = @_;
  if (! $self->check_messages()) {
    if ($self->opts->mode =~ /^my-/) {
      $self->load_my_extension();
    } else {
      $self->rebless('Classes::Filesystem');
    }
  }
  return $self;
}


package Classes::Generic;
our @ISA = qw(Classes::Device);
use strict;

sub init {
  my($self) = @_;
  if ($self->mode =~ /something specific/) {
  } else {
    bless $self, 'Monitoring::GLPlugin';
    $self->no_such_mode();
  }
}
