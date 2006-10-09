package Integration::Task::InplaceEdit;

use strict;
use warnings;

use Integration::Task;
our @ISA = qw(Integration::Task);

{

my %Edits_of;

sub new {
  my ($class, %params) = @_;
  my $self = $class->SUPER::new(%params);
  $Edits_of{$self} = [];
  return $self;
}

sub process {
  ### Performs an in place edit on a file defined by {{source}}. The resulting, edited file is placed in {{destination}}. Edits to make can be added as key value pairs using {{add_edit}}.
  my $self = shift;
  open (INPUT, $self->source) or die;
  my @lines = <INPUT>;
  my @update = ();
  close INPUT;
  warn "INPLACE EDIT!";
  foreach my $edit_array (@{ $self->edits }) {
    my $search = $edit_array->[0];
    my $replace = $edit_array->[1];
    warn "SEARCH: " . $search;
    warn "REPLACE: " . $replace;
    open (OUTPUT, ">", $self->destination);
    my $count = 0;
    foreach my $line (@lines) {
      my $print = $line; 
      chomp $print;
      if ($print =~ /$search/) {
        $print =~ s/$search/$replace/g;
      }
      print OUTPUT $print . "\n";
      $update[$count] = $print;
      $count++;
    }
    @lines = @update;
    close OUTPUT;
  }
  return 1;
}

sub add_edit {
  my ($self, $search, $replace) = @_;
  push @{ $self->edits }, [$search => $replace];
}

sub edits {
  ### a
  my $self = shift;
  $Edits_of{$self} = shift if @_;
  return $Edits_of{$self};
}


sub DESTROY {
  my $self = shift;
  delete $Edits_of{$self}; 
}

}

1;
