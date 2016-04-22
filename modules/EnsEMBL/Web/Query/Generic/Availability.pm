package EnsEMBL::Web::Query::Generic::Availability;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Query::Generic::Base);

use List::Util qw(min max);

sub table_info {
  my ($self,$args,$table_name,$type) = @_;

  return $self->species_defs->table_info(
    $args->{'species'},
    $type||$args->{'type'},
    $table_name
  );
}

sub regulation_db_adaptor {
  my ($self,$args) = @_;

  return $self->source('Adaptors')->regulation_db_adaptor($args->{'species'});
}

sub variation_db_adaptor {
  my ($self,$args,$type) = @_;

  $type ||= 'variation';
  return $self->source('Adaptors')->variation_db_adaptor($type,$args->{'species'});
}

sub pancompara_db_adaptor {
  my ($self,$args) = @_;

  return $self->source('Adaptors')->pancompara_db_adaptor;
}

sub compara_member {
  my ($self,$args) = @_;

  return $self->source('Adaptors')->compara_member($args->{'gene'}->stable_id);
}

sub pancompara_member {
  my ($self,$args) = @_;

  return $self->source('Adaptors')->pancompara_member($args->{'gene'}->stable_id);
}

sub default_gene_tree {
  my ($self,$args,$member) = @_;

  return $self->source('Adaptors')->default_gene_tree($args->{'species'},$member);
}

sub phenotype_feature_adaptor {
  my ($self,$args) = @_;

  return $self->source('Adaptors')->phenotype_feature_adaptor($args->{'species'});
}

sub alt_allele_group_adaptor {
  my ($self,$args) = @_;

  return $self->source('Adaptors')->alt_allele_group_adaptor($args->{'species'});
}

sub sd_config {
  my ($self,$args,$var) = @_;

  return $self->source('SpeciesDefs')->config($args->{'species'},$var);
}

sub sd_multi {
  my ($self,$args,$type,$species) = @_;

  $type ||= $args->{'type'};
  $species ||= $args->{'species'};
  return $self->source('SpeciesDefs')->multi($type,$species);
}

sub multiX {
  my ($self,$var) = @_;

  return $self->source('SpeciesDefs')->multiX($var);
}

sub super_availability {
  my ($self,$args) = @_;

  my $dbs =
    $self->source('SpeciesDefs')->list_databases($args->{'species'});
  my $hash = { map {; "database:$_" => 1 } @$dbs };

  return $hash;
}


sub fixup_gene {
  my ($self,$key,$sk,$tk) = @_;

  if($self->phase eq 'pre_process') {
    my $data = $self->data;
    $data->{$key} = $data->{$key}->stable_id if $data->{$key};
  } elsif($self->phase eq 'pre_generate') {
    my $data = $self->data;
    #$data->{"__orig_$key"} = $data->{$key};
    my $ad = $self->source('Adaptors');
    if($data->{$key}) {
      $data->{$key} =
        $ad->gene_by_stableid($data->{$sk},$data->{$tk},$data->{$key});
    }
  }
}

sub loop_genes {
  my ($self,$args) = @_;

  my $all = $self->source('Adaptors')->
              gene_adaptor($args->{'species'},$args->{'type'})->fetch_all;
  my @out;
  foreach my $g (@$all) {
    my %out = %$args;
    $out{'species'} = $args->{'species'};
    $out{'type'} = $args->{'type'};
    $out{'gene'} = $g->stable_id;
    $out{'__name'} = $g->stable_id;
    push @out,\%out;
  }
  return \@out;
}

1;
