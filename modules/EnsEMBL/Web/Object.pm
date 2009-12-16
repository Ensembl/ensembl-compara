package EnsEMBL::Web::Object;

### Base object class - all Ensembl web objects are derived from this class,
### this class is derived from proxiable - as it is usually proxied through an
### {{EnsEMBL::Web::Proxy}} object to handle the dynamic multiple inheritance 
### functionality.

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Proxy::Factory;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Text::FeatureParser;
use EnsEMBL::Web::Tools::Misc qw(get_url_content);

use base qw(EnsEMBL::Web::Proxiable);

sub counts            { return {}; }
sub availability      { return {}; }
sub can_export        { return 0; }
sub Obj               { return $_[0]{'data'}{'_object'}; }       # Gets the underlying Ensembl object wrapped by the web object
sub highlights_string { return join '|', @{$_[0]->highlights}; } # Returns the highlights area as a | separated list for passing in URLs.

sub count_alignments {
  my $self = shift;
  
  my $species = $self->species;
  my %alignments = $self->species_defs->multi('DATABASE_COMPARA', 'ALIGNMENTS');
  my $c = { all => 0, pairwise => 0 };
  
  foreach (grep $_->{'species'}{$species}, values %alignments) {
    $c->{'all'}++ ;
    $c->{'pairwise'}++ if $_->{'class'} =~ /pairwise_alignment/;
  }
  
  $c->{'multi'} = $c->{'all'} - $c->{'pairwise'};
  
  return $c; 
}

sub _availability { 
  my $self = shift;
  
  my $hash = { map { ('database:'. lc(substr $_, 9) => 1) } keys %{$self->species_defs->databases} };
  $hash->{'database:compara'} = 1 if $self->species_defs->compara_like_databases;
  $hash->{'logged_in'} = 1 if $ENSEMBL_WEB_REGISTRY->get_user;
  
  return $hash;
}

sub core_params {
  my $self = shift;
  
  my $location     = $self->core_objects->location;
  my $gene         = $self->core_objects->gene;
  my $transcript   = $self->core_objects->transcript;
  my $params       = [];
  
  push @$params, sprintf 'r=%s:%s-%s', $location->seq_region_name, $location->start, $location->end if $location;
  push @$params, 'g=' . $gene->stable_id if $gene;
  push @$params, 't=' . $transcript->stable_id if $transcript;
  
  return $params;
}

sub prefix {
  my ($self, $value) = @_;
  $self->{'prefix'} = $value if $value;
  return $self->{'prefix'};
}

# Gets the database name used to create the object
sub get_db {
  my $self = shift;
  my $db = $self->param('db') || 'core';
  return $db eq 'est' ? 'otherfeatures' : $db;
}

# Data interface attached to object
sub interface {
  my $self = shift;
  $self->{'interface'} = shift if @_;
  return $self->{'interface'};
}

# Command object attached to proxy object
sub command {
  my $self = shift;
  $self->{'command'} = shift if (@_);
  return $self->{'command'};
}

sub get_adaptor {
  my ($self, $method, $db, $species) = @_;
  
  $db      = 'core' if !$db;
  $species = $self->species if !$species;
  
  my $adaptor;
  eval { $adaptor = $self->database($db, $species)->$method(); };

  if ($@) {
    warn $@;
    $self->problem('fatal', "Sorry, can't retrieve required information.", $@);
  }
  
  return $adaptor;
}

# The highlights array is passed between web-requests to highlight selected items (e.g. Gene around
# which contigview had been rendered. If any data is passed this is stored in the highlights array
# and an arrayref of (unique) elements is returned.
sub highlights {
  my $self = shift;
  
  if (!exists( $self->{'data'}{'_highlights'})) {
    my %highlights = map { ($_ =~ /^(URL|BLAST_NEW):/ ? $_ : lc $_) => 1 } grep $_, map { split /\|/, $_ } $self->param('h'), $self->param('highlights');
    
    $self->{'data'}{'_highlights'} = [ grep $_, keys %highlights ];
  }
  
  if (@_) {
    my %highlights = map { ($_ =~ /^(URL|BLAST_NEW):/ ? $_ : lc $_) => 1 } @{$self->{'data'}{'_highlights'}||[]}, map { split /\|/, $_ } @_;
    
    $self->{'data'}{'_highlights'} = [ grep $_, keys %highlights ];
  }
  
  return $self->{'data'}{'_highlights'};
}

# Returns the type of seq_region in "human readable form" (in this case just first letter captialised)
sub seq_region_type_human_readable {
  my $self = shift;
  
  if (!$self->can('seq_region_type')) {
    $self->{'data'}->{'_drop_through_'} = 1;
    return;
  }
  
  return ucfirst $self->seq_region_type;
}

# Returns the type/name of seq_region in human readable form - if the coord system type is part of the name this is dropped.
sub seq_region_type_and_name {
  my $self = shift;
  
  if (!$self->can('seq_region_name')) {
    $self->{'data'}->{'_drop_through_'} = 1;
    return;
  }
  
  my $coord = $self->seq_region_type_human_readable;
  my $name  = $self->seq_region_name;
  
  if ($name =~ /^$coord/i) {
    return $name;
  } else {
    return "$coord $name";
  }
}

sub gene_description {
  my $self = shift;
  my $gene = shift || $self->gene;
  my %description_by_type = ('bacterial_contaminant' => 'Probable bacterial contaminant');
  
  if ($gene) {
    return $gene->description || $description_by_type{$gene->biotype} || 'No description';
  } else {
    return 'No description';
  }
}

sub generate_query_url {
  my $self = shift;
  my $q_hash = $self->generate_query_hash;
  return join ';', map { "$_=$q_hash->{$_}" } keys %$q_hash;
}

sub fetch_homologues_of_gene_in_species {
  my $self = shift;
  my ($gene_stable_id, $paired_species) = @_;
  
  return [] unless $self->database('compara');

  my $ma = $self->database('compara')->get_MemberAdaptor;
  my $qy_member = $ma->fetch_by_source_stable_id('ENSEMBLGENE', $gene_stable_id);
  
  return [] unless defined $qy_member; 

  my $ha = $self->database('compara')->get_HomologyAdaptor;
  my @homologues;
  
  foreach my $homology (@{$ha->fetch_all_by_Member_paired_species($qy_member, $paired_species, ['ENSEMBL_ORTHOLOGUES'])}){
    foreach my $member_attribute (@{$homology->get_all_Member_Attribute}) {
      my ($member, $attribute) = @$member_attribute;
      next if $member->stable_id eq $qy_member->stable_id;
      push @homologues, $member;  
    }
  }
  
  return \@homologues;
}

sub bp_to_nearest_unit {
  my $self = shift ;
  my ($bp, $dp) = @_;
  
  $dp = 2 unless defined $dp;
  
  my @units = qw(bp Kb Mb Gb Tb);
  
  my $power_ranger = int((length(abs $bp) - 1) / 3);
  my $unit         = $units[$power_ranger];
  my $value        = int($bp / (10 ** ($power_ranger * 3)));
  my $unit_str;
  
  if ($unit ne 'bp'){
    $unit_str = sprintf "%.${dp}f%s", $bp / (10 ** ($power_ranger * 3)), " $unit";
  } else {
    $unit_str = "$value $unit";
  }
  
  return $unit_str;
}

sub fetch_userdata_by_id {
  my ($self, $record_id) = @_;
  
  return unless $record_id;
  
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my $data = {};

  my ($status, $type, $id) = split '-', $record_id;

  if ($type eq 'url' || ($type eq 'upload' && $status eq 'temp')) {
    my ($content, $format);

    my $tempdata = {};
    if ($status eq 'temp') {
      $tempdata = $self->get_session->get_data('type' => $type, 'code' => $id);
    } else {
      my $record = $user->urls($id);
      $tempdata = { 'url' => $record->url };
    }
    
    my $parser = new EnsEMBL::Web::Text::FeatureParser($self->species_defs);
    
    if ($type eq 'url') {
      my $response = get_url_content($tempdata->{'url'});
      $content = $response->{'content'};
    } else {
      my $file = new EnsEMBL::Web::TmpFile::Text(filename => $tempdata->{'filename'});
      $content = $file->retrieve;
      return {} unless $content;
    }
    
    $parser->parse($content, $tempdata->{'format'});
    $data = { 'parser' => $parser };
  } else {
    my $fa = $self->database('userdata', $self->species)->get_DnaAlignFeatureAdaptor;
    my @records = $user->uploads($id);
    my $record = $records[0];
    
    if ($record) {
      my @analyses = ($record->analyses);
      
      foreach (@analyses) {
        next unless $_;
        $data->{$_} = {'features' => $fa->fetch_all_by_logic_name($_), 'config' => {}};
      }
    }
  }
  
  return $data;
}

# There may be occassions when a script needs to work with features of
# more than one type. in this case we create a new {{EnsEMBL::Web::Proxy::Factory}}
# object for the alternative data type and retrieves the data (based on the standard URL
# parameters for the new factory) attach it to the universal datahash {{__data}}
sub alternative_object_from_factory {
  my ($self, $type) = @_;
  
  my $t_fact = new EnsEMBL::Web::Proxy::Factory($type, $self->__data);
  
  if ($t_fact->can('createObjects')) {
    $t_fact->createObjects;
    $self->__data->{lc $type}  = $t_fact->DataObjects;
    $self->__data->{'objects'} = $t_fact->__data->{'objects'};
  }
}

1;
