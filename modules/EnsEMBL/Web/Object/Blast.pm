package EnsEMBL::Web::Object::Blast;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Object;
use EnsEMBL::Web::Proxy::Object;

our @ISA = qw(EnsEMBL::Web::Object);

sub get_species_values_for_dropdown {

  my $self = shift;
  my $species = $self->species;
  my $script = $self->script;

  my %all_species = %{$self->current_spp};
  my @sorted = sort {$all_species{$a} cmp $all_species{$b}} keys %all_species;
  my @species_values = ({'name'=>'All species', 'value'=>'0'});
  foreach my $id (@sorted) {
    my $name = $all_species{$id};
    $name =~ s/\_/ /g;
    push @species_values, { 'name' => $name, 'value' => $id };
  }
  return @species_values;

}

#sub request {
#   my ($self, $request) = @_;
#   if ($request) {
#     $self->__data->{'request'} = $request;
#   }
#   return $self->__data->{'request'};
#}

sub current_spp   { return $_[0]->Obj->{'current_spp'};   }
sub request       { return $_[0]->Obj->{'request'};   }
sub job		  { return $_[0]->Obj->{'ticket'};   }
sub blast_adaptor { return $_[0]->Obj->{'blast_adaptor'};   }

sub species_for_id {
  my ($self, $id) = @_;
  my %all_species = %{$self->current_spp};
  my $species = $all_species{$id}; 
  $species =~ s/_/ /g;
  return $species;
}

sub script {
   return "blastview";
}

sub __objecttype {
  return "Blast";
}

1;
