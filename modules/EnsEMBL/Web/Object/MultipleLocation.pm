package EnsEMBL::Web::Object::MultipleLocation;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Object;
our @ISA = qw(EnsEMBL::Web::Object);
use POSIX qw(floor ceil);


sub Obj { 
  return $_[0]{'data'}{'_object'}[0]->Obj; 
}

sub species_list { return map { $_->real_species } $_[0]->Locations; }

sub species_and_seq_region_list { return map {$_->real_species.':'.$_->seq_region_name } $_[0]->Locations; }	

sub Locations { return @{$_[0]{data}{_object}}; }

sub PrimaryLocation {
  return $_[0]{object}[1]{_object}[0];
}

sub centrepoint      { return ( $_[0]->Obj->{'seq_region_end'} + $_[0]->Obj->{'seq_region_start'} ) / 2; }
sub length           { return $_[0]->Obj->{'seq_region_end'} - $_[0]->Obj->{'seq_region_start'} + 1; }

sub slice              :lvalue { $_[0]->Obj->{'slice'};              }
sub attach_slice       { $_[0]->Obj->{'slice'} = $_[1];              }
sub real_species       :lvalue { $_[0]->Obj->{'real_species'};       }
sub raw_feature_strand :lvalue { $_[0]->Obj->{'raw_feature_strand'}; }
sub strand             :lvalue { $_[0]->Obj->{'strand'};             }
sub name               :lvalue { $_[0]->Obj->{'name'};               }
sub type               :lvalue { $_[0]->Obj->{'type'};               }
sub synonym            :lvalue { $_[0]->Obj->{'synonym'};            }
sub seq_region_name    :lvalue { $_[0]->Obj->{'seq_region_name'};    }
sub seq_region_start   :lvalue { $_[0]->Obj->{'seq_region_start'};   }
sub seq_region_end     :lvalue { $_[0]->Obj->{'seq_region_end'};     }
sub seq_region_strand  :lvalue { $_[0]->Obj->{'seq_region_strand'};  }
sub seq_region_type    :lvalue { $_[0]->Obj->{'seq_region_type'};    }
sub seq_region_length  :lvalue { $_[0]->Obj->{'seq_region_length'};  }

=head2 location

    Arg[1]      : (optional) String
                  Name of slice
    Example     : my $location = $self->DataObj->name;
    Description : getter/setter for slice name
    Return type : String for slice name

=cut

sub location {
  my $self = shift;
  my $region = $self->seq_region_name;  
  my $start = $self->seq_region_start;
  my $end = $self->seq_region_end;
  return "$region:$start:$end";
}

sub generate_query_hash {
  my $self = shift;
  my($primary, @secondary) = $self->Locations;
  my $q_hash = {
    'c' => $primary->seq_region_name.':'.$primary->centrepoint.':'.$primary->seq_region_strand,
    'w' => $primary->length,
    'h' => $self->highlights_string()
  };
  my $counter = 1;
  foreach my $secondary (@secondary) {
    $q_hash->{"c$counter"} = $secondary->seq_region_name.':'.$secondary->centrepoint.':'.$secondary->seq_region_strand;
    $q_hash->{"w$counter"} = $secondary->length;
    $q_hash->{"s$counter"} = $self->species_defs->ENSEMBL_SHORTEST_ALIAS->{$secondary->real_species};
    $counter++;
  }
  return $q_hash;
}

sub generate_dotter_bin_file {
  my( $self, $zoom ) = @_;
  my( $name, $seq );
  my($ref, $hom) = $self->Locations;
  ( $seq = $ref->slice->seq ) =~ s/(.{60})/$1\n/ig;
  my $temp_root = $self->species_defs->ENSEMBL_TMP_DIR;
  my $ref_filename = $temp_root.'/'.$self->temp_file_create('fa');
  $name = "@{[$ref->real_species]}: @{[$ref->seq_region_type_and_name]} @{[$self->thousandify(floor($ref->seq_region_start))]} - @{[$ref->thousandify(ceil($self->seq_region_end))]}";
  open(O,">$ref_filename") or die "Cannot open REF FA file $ref_filename: $!\n";
  print O ">$name\n$seq\n";
  close(O);
  my $hom_filename = $temp_root.'/'.$self->temp_file_create('fa');
  ( $seq = $hom->slice->seq ) =~ s/(.{60})/$1\n/ig;
  $name = "@{[$hom->real_species]}: @{[$hom->seq_region_type_and_name]} @{[$self->thousandify(floor($hom->seq_region_start))]} - @{[$hom->thousandify(ceil($self->seq_region_end))]}";
  open(O,">$hom_filename") or die "Cannot open HOM FA file $ref_filename: $!\n";
  print O ">$name\n$seq\n";
  close(O);
  my $out_file = $temp_root.'/'.$self->temp_file_create('out');
  system( $self->species_defs->ENSEMBL_BINARIES_PATH."/dotter -b $out_file -m .50 -z $zoom $ref_filename $hom_filename" );
  unlink( $ref_filename );
  unlink( $hom_filename );
  return $out_file;
}

1;
