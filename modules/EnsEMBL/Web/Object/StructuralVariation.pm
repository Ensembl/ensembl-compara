package EnsEMBL::Web::Object::StructuralVariation;

### NAME: EnsEMBL::Web::Object::StructuralVariation
### Wrapper around a Bio::EnsEMBL::StructuralVariation

### PLUGGABLE: Yes, using Proxy::Object

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Cache;

use base qw(EnsEMBL::Web::Object);

our $MEMD = new EnsEMBL::Web::Cache;

sub _filename {
  my $self = shift;
  my $name = sprintf '%s-structural-variation-%d-%s-%s',
    $self->species,
    $self->species_defs->ENSEMBL_VERSION,
    'structural variation',
    $self->name;
  $name =~ s/[^-\w\.]/_/g;
  return $name;
}

sub availability {
  my $self = shift;

  if (!$self->{'_availability'}) {
    my $availability = $self->_availability;
    my $obj = $self->Obj;

    if ($obj->isa('Bio::EnsEMBL::Variation::StructuralVariation')) {
      $availability->{'structural_variation'} = 1;
    }
		
		if (scalar @{$obj->get_all_SupportingStructuralVariants} != 0) {
			$availability->{'supporting_structural_variation'} = 1;
		}

    $self->{'_availability'} = $availability;
  }
  return $self->{'_availability'};
}


sub short_caption {
  my $self = shift;

  my $type = 'Structural variation';
	if ($self->class eq 'CNV_PROBE') {
 		$type = 'CNV probe';
 	}
  my $short_type = 'S. Var';
  return $type.' displays' unless shift eq 'global';

  my $label = $self->name;
  return length $label > 30 ? "$short_type: $label" : "$type: $label";
}


sub caption {
 my $self = shift;
 my $type = 'Structural variation';
 if ($self->class eq 'CNV_PROBE') {
 	$type = 'Copy number variation probe';
 }
 my $caption = $type.': '.$self->name;

 return $caption;
}

sub name               { my $self = shift; return $self->Obj->variation_name;                      }
sub class              { my $self = shift; return $self->Obj->class;                               }
sub source             { my $self = shift; return $self->Obj->source;                              }
sub source_description { my $self = shift; return $self->Obj->source_description;                  }
sub study_name         { my $self = shift; return $self->Obj->study_name;                          }
sub study_description  { my $self = shift; return $self->Obj->study_description;                   }
sub study_url          { my $self = shift; return $self->Obj->study_url;                           }
sub external_reference { my $self = shift; return $self->Obj->external_reference;                  }
sub supporting_sv      { my $self = shift; return $self->Obj->get_all_SupportingStructuralVariants;}    

sub variation_feature_mapping { 
  my $self = shift;
  my %data;
	my $obj = $self->Obj;
  my $id = $obj->dbID;
  $data{$id}{Chr}            = $obj->slice->seq_region_name;
  $data{$id}{start}          = $obj->start;
  $data{$id}{end}            = $obj->end;
  $data{$id}{strand}         = $obj->strand;
  $data{$id}{transcript_vari} = undef;

  return \%data;
}
1;
