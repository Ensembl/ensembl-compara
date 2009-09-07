package EnsEMBL::Web::Object;

### Base object class - all Ensembl web objects are derived from this class,
### this class is derived from proxiable - as it is usually proxied through an
### {{EnsEMBL::Web::Proxy}} object to handle the dynamic multiple inheritance 
### functionality.

use strict;
use warnings;
no warnings "uninitialized";
use CGI qw(escape);

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Tools::Misc;
use EnsEMBL::Web::Text::FeatureParser;
use EnsEMBL::Web::Document::Image;
use Bio::EnsEMBL::DrawableContainer;
use Bio::EnsEMBL::VDrawableContainer;

use base qw(EnsEMBL::Web::Proxiable);


sub counts { return {}; } 

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
  my $hash = {
    map { ('database:'.lc(substr($_,9)) => 1) } keys %{ $self->species_defs->databases }
  };
  $hash->{'database:compara'} = 1 if $self->species_defs->compara_like_databases;
  return $hash;
}

sub availability { return {}; }

sub core_params {
  my $self = shift;
  my $params = [];
  if ($self->core_objects->location) {
    push @$params, 'r='.$self->core_objects->location->seq_region_name.':'.$self->core_objects->location->start.'-'
                    .$self->core_objects->location->end;
  }
  if ($self->core_objects->gene) {
    push @$params, 'g='.$self->core_objects->gene->stable_id;
  }
  if ($self->core_objects->transcript) {
    push @$params, 't='.$self->core_objects->transcript->stable_id;
  }
  return $params;
}

sub EnsemblObject   {
### Deprecated
### Sets/gets the underlying Ensembl object wrapped by the web object
  my $self = shift;
  warn "EnsemblObject - TRY TO AVOID - THIS NEEDS TO BE REMOVED... Use Obj instead...";
  $self->{'data'}{'_object'}    = shift if @_;
  return $self->{'data'}{'_object'};
}

sub prefix {
  ### a
  my ($self, $value) = @_;
#  warn "PREFIX: $value";
  if ($value) {
    $self->{'prefix'} = $value;
  }
  return $self->{'prefix'};
}

sub Obj {
### a 
### Gets the underlying Ensembl object wrapped by the web object
  return $_[0]{'data'}{'_object'};
}


sub get_adaptor {
  my ($self, $method, $db, $species) = @_;
  $db = 'core' if !$db;
  $species = $self->species if !$species;
  my $adaptor;
  eval { $adaptor =  $self->database($db, $species)->$method(); };

  if( $@ ) {
    warn ($@);
    $self->problem('fatal', "Sorry, can't retrieve required information.",$@);
  }
  return $adaptor;
}

#Gets the database name used to create the object
sub get_db {
  my $self = shift;
  my $db = $self->param('db') || 'core';
  return $db eq 'est' ? 'otherfeatures' : $db;
}

sub dataobj { 
### Deprecated
### a 
### Gets the underlying Ensembl object wrapped by the web object
  warn "dataobj - TRY TO AVOID - THIS NEEDS TO BE REMOVED... Use Obj instead...";
  return $_[0]->Obj;
}

sub highlights {
### a
### The highlights array is passed between web-requests to highlight selected items (e.g. Gene around
### which contigview had been rendered. If any data is passed this is stored in the highlights array
### and an arrayref of (unique) elements is returned.
  my $self = shift;
  unless( exists( $self->{'data'}{'_highlights'}) ) {
    my @highlights = $self->param('h');
    push @highlights, $self->param('highlights');
    my %highlights = map { ($_ =~ /^(URL|BLAST_NEW):/ ? $_ : lc($_)) =>1 } grep {$_} map { split /\|/, $_ } @highlights;
    $self->{'data'}{'_highlights'} = [grep {$_} keys %highlights];
  }
  if( @_ ) {
    my %highlights = map { ($_ =~ /^(URL|BLAST_NEW):/ ? $_ : lc($_)) =>1 } @{$self->{'data'}{'_highlights'}||[]}, map { split /\|/, $_ } @_;
    $self->{'data'}{'_highlights'} = [grep {$_} keys %highlights];
  }
  return $self->{'data'}{'_highlights'};
}

sub highlights_string {
### Returns the highlights area as a | separated list for passing in URLs.
  return join '|', @{$_[0]->highlights};
}

sub mapview_link {
### Parameter $feature
### Returns name of seq_region $feature is on. If the passed features is
### on a "real chromosome" then this is encapsulated in a link to mapview.
  my( $self, $feature ) = @_;
  my $coords = $feature->coord_system_name; 
  my $name   = $feature->seq_region_name;
  my %real_chr = map { $_, 1 } @{$self->species_defs->ENSEMBL_CHROMOSOMES};
  
  return $real_chr{ $name } ?
    sprintf( '<a href="%s">%s</a>', $self->URL( 'script' => 'mapview', 'chr' => $name ), $name ) : 
    $name;
}

sub location_URL {
### Parameters: $feature, $script, $context
### Returns a link to a contigview style display, based on feature, with context
  my( $self, $feature, $script, $context ) = @_;
  my $name  = $feature->seq_region_name;
  my $start = $feature->start;
  my $end   = $feature->end;
     $script = $script||'contigview';
     $script = 'cytoview' if $script eq 'contigview' && $self->species_defs->NO_SEQUENCE;

  return $self->URL( 'script' => $script||'contigview', 'l'=>"$name:$start-$end", 'context' => $context || 0 );
}

sub      URL {
### (%params) Returns an absolute link to another script. %params hash is used as the parameters for the link.
### Note keys species and script are handled differently - as these are not passed as parameters but set the
### species and script name respectively in the URL
  my $self = shift; return $self->_URL( 0,@_ );
}

sub full_URL {
### Returns a full (http://...) link to another script. Wrapper around {{_URL}} function
  my $self = shift; return $self->_URL( 1,@_ );
}

sub _URL { 
### Returns either a full link or absolute link to a script
  my( $self, $full, %details ) = @_;
  my $URL  = $full ? $self->species_defs->ENSEMBL_BASE_URL : '';
     $URL .=  "/".(exists $details{'species'} ? $details{'species'} : $self->species);
     $URL .=  exists $details{'script'}  ? "/$details{'script'}"  : '';
  my $extra = join( ";", map { /^(script|species)$/ ? () : sprintf('%s=%s', $_, $details{$_}) } keys %details );
  $URL .= "?$extra" if $extra;
  return $URL;
}

sub seq_region_type_human_readable {
### Returns the type of seq_region in "human readable form" (in this case just first letter captialised)
  my $self = shift;
  unless( $self->can('seq_region_type') ) {
    $self->{'data'}->{'_drop_through_'} = 1;
    return;
  }
  return ucfirst( $self->seq_region_type );
}

sub seq_region_type_and_name {
### Returns the type/name of seq_region in human readable form - if the coord system type is part of the name this is dropped.
  my $self = shift;
  unless( $self->can('seq_region_name') ) {
    $self->{'data'}->{'_drop_through_'} = 1;
    return;
  }
  my $coord = $self->seq_region_type_human_readable;
  my $name  = $self->seq_region_name;
  if( $name =~/^$coord/i ) {
    return $name;
  } else {
    return "$coord $name";
  }
}

sub gene_description {
  my $self = shift;
  my $gene = shift || $self->gene;
  my %description_by_type = ( 'bacterial_contaminant' => "Probable bacterial contaminant" );
  if( $gene ) {
    return $gene->description() || $description_by_type{ $gene->biotype } || 'No description';
  } else {
    return 'No description';
  }
}

sub generate_query_url {
  my $self = shift;
  my $q_hash = $self->generate_query_hash;
  return join ';', map { "$_=$q_hash->{$_}" } keys %$q_hash;
}

# DEPRECATED - use EnsEMBL::Web::Component
sub new_image {
  my $self = shift;
  my $species_defs = $self->species_defs;
  my $timer = $species_defs->timer;
  my $image = EnsEMBL::Web::Document::Image->new( $species_defs );
     $image->drawable_container = Bio::EnsEMBL::DrawableContainer->new( @_ );
     if ($self->prefix) {
       $image->prefix($self->prefix);
     }
  return $image;
}

# DEPRECATED - use EnsEMBL::Web::Component
sub new_vimage {
  my $self  = shift;
  my $image = EnsEMBL::Web::Document::Image->new( $self->species_defs );
     $image->drawable_container = Bio::EnsEMBL::VDrawableContainer->new( @_ );
  return $image;
}

# DEPRECATED - use EnsEMBL::Web::Component
sub new_karyotype_image {
  my $self = shift;
  my $image = EnsEMBL::Web::Document::Image->new( $self->species_defs );
     $image->{'object'} = $self;
  return $image;
}

sub fetch_homologues_of_gene_in_species {
    my $self = shift;
    my ($gene_stable_id, $paired_species) = @_;
    return [] unless ($self->database('compara'));

    my $ma = $self->database('compara')->get_MemberAdaptor;
    my $qy_member = $ma->fetch_by_source_stable_id("ENSEMBLGENE",$gene_stable_id);
    return [] unless (defined $qy_member); 

    my $ha = $self->database('compara')->get_HomologyAdaptor;
    my @homologues;
    foreach my $homology (@{$ha->fetch_all_by_Member_paired_species($qy_member, $paired_species, ['ENSEMBL_ORTHOLOGUES'])}){
      foreach my $member_attribute (@{$homology->get_all_Member_Attribute}) {
        my ($member, $attribute) = @{$member_attribute};
        next if ($member->stable_id eq $qy_member->stable_id);
        push @homologues, $member;  
      }
    }    
    return \@homologues;
}

sub bp_to_nearest_unit {
    my $self = shift ;
    my ($bp,$dp) = @_;
    $dp = 2 unless defined $dp;
    
    my @units = qw( bp Kb Mb Gb Tb );
    
    my $power_ranger = int( ( length( abs($bp) ) - 1 ) / 3 );
    my $unit = $units[$power_ranger];
    my $unit_str;

    my $value = int( $bp / ( 10 ** ( $power_ranger * 3 ) ) );
      
    if ( $unit ne "bp" ){
    $unit_str = sprintf( "%.${dp}f%s", $bp / ( 10 ** ( $power_ranger * 3 ) ), " $unit" );
    }else{
    $unit_str = "$value $unit";
    }
    return $unit_str;
}


sub referer { return $_[0]->param('ref')||$ENV{'HTTP_REFERER'}; }

sub _help_URL {
  my( $self, $options ) = @_;
  my $ref = CGI::escape( $self->referer );
  my $URL = "/@{[$self->species]}/helpview?";
  my @params;
  while (my ($k, $v) = each (%$options)) {
    push @params, "$k=$v";
  } 
  push @params, "ref=$ref";
  $URL .= join(';', @params);
  return $URL;
}

sub fetch_userdata_by_id {
  my ($self, $record_id) = @_;
  return unless $record_id;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my $data = {};

  my ($status, $type, $id) = split('-', $record_id);

  if ($type eq 'url' || ($type eq 'upload' && $status eq 'temp')) {
    my ($content, $format);

    my $tempdata = {};
    if ($status eq 'temp') {
      $tempdata = $self->get_session->get_data('type' => $type, 'code' => $id);
    }
    else {
      my $record = $user->urls($id);
      $tempdata = {'url' => $record->url};
    }
    my $parser = EnsEMBL::Web::Text::FeatureParser->new($self->species_defs);
    if ($type eq 'url') {
      $content = EnsEMBL::Web::Tools::Misc::get_url_content( $tempdata->{'url'} );
    }
    else {
      my $file = new EnsEMBL::Web::TmpFile::Text( filename => $tempdata->{'filename'} );
      $content = $file->retrieve;
      return {} unless $content;
    }
    $parser->parse($content, $tempdata->{'format'} );
    $data = {'parser' => $parser};
  }
  else {
    my $fa = $self->database('userdata', $self->species)->get_DnaAlignFeatureAdaptor;
    my @records = $user->uploads($id);
    my $record = $records[0];
    my @analyses = ($record->analyses);
    foreach (@analyses) {
      next unless $_;
      $data->{$_} = {'features' => $fa->fetch_all_by_logic_name($_), 'config' => {}};
    }
  }

  return $data;
}


sub alternative_object_from_factory {
### There may be occassions when a script needs to work with features of
### more than one type. in this case we create a new {{EnsEMBL::Web::Proxy::Factory}}
### object for the alternative data type and retrieves the data (based on the standard URL
### parameters for the new factory) attach it to the universal datahash {{__data}}

  my( $self,$type ) =@_;
  my $t_fact = EnsEMBL::Web::Proxy::Factory->new( $type, $self->__data );
  if( $t_fact->can( 'createObjects' ) ) {
    $t_fact->createObjects;
    $self->__data->{lc($type)} = $t_fact->DataObjects;
    $self->__data->{'objects'} = $t_fact->__data->{'objects'};
  }
}

sub interface {
### Data interface attached to object
    my $self = shift;
    $self->{'interface'} = shift if (@_);
    return $self->{'interface'};
}

sub command {
### Command object attached to proxy object
    my $self = shift;
    $self->{'command'} = shift if (@_);
    return $self->{'command'};
}

sub can_export {
  return 0;
}

1;
