=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Object::LRG;

use strict;

use Time::HiRes qw(time);
use Bio::EnsEMBL::Compara::GenomeDB;
use Bio::EnsEMBL::Compara::Homology;
use Exporter;

use base qw(EnsEMBL::Web::Object);

sub create_features {
    my $self = shift;
    return {'LRG' => $self->_generic_create( 'Slice', 'fetch_by_region' ) };
}

sub get_transcript {
  my $self        = shift;
  my $param       = $self->hub->param('lrgt');
  my $transcripts = $self->get_all_transcripts;
  return $param ? grep $_->stable_id eq $param, @$transcripts : $transcripts->[0];
}


sub default_action {
  my $self         = shift;
  my $availability = $self->availability;
  return $availability->{'lrg'} ? 'Summary' : 'Genome';
}

sub _generic_create {
  my( $self, $object_type, $accessor, $db, $id, $flag ) = @_; 
  $db ||= 'core';
  if (!$id ) {
#    my @ids = $self->param( 'lrg' );

    my @ids = @{$self->species_defs->LRG_REGIONS || []};

    $id = join(' ', @ids);
  }
  elsif (ref($id) eq 'ARRAY') {
    $id = join(' ', @$id);
  }

  ## deal with xrefs
  my $xref_db;
  if ($object_type eq 'DBEntry') {
    my @A = @$db;
    $db = $A[0];
    $xref_db = $A[1];
  }

  if( !$id ) {
    return undef; # return empty object if no id
  }
  else {
# Get the 'central' database (core, est, vega)
    my $db_adaptor  = $self->database(lc($db));
    unless( $db_adaptor ){
      $self->problem( 'fatal', 'Database Error', "Could not connect to the $db database." );
      return undef;
    }
    my $adaptor_name = "get_${object_type}Adaptor";
    my $features = [];
    $id =~ s/\s+/ /g;
    $id =~s/^ //;
    $id =~s/ $//;

    foreach my $fid ( split /\s+/, $id ) {
      my $t_features;
      if ($xref_db) {
        eval {
         $t_features = [$db_adaptor->$adaptor_name->$accessor($xref_db, $fid)];
        };
      }
      elsif ($accessor eq 'fetch_by_stable_id') { ## Hack to get gene stable IDs to work!
        eval {
         $t_features = [$db_adaptor->$adaptor_name->$accessor($fid)];
        };
      }
      elsif ($accessor eq 'fetch_by_region') { ## Hack to get gene stable IDs to work!
        eval {
         $t_features = [$db_adaptor->$adaptor_name->$accessor(undef, $fid)];
        };
      }
      else {
        eval {
         $t_features = $db_adaptor->$adaptor_name->$accessor($fid);
        };
      }

      ## if no result, check for unmapped features
      if ($t_features && ref($t_features) eq 'ARRAY') {
        if (!@$t_features) {
          my $uoa = $db_adaptor->get_UnmappedObjectAdaptor;
          $t_features = $uoa->fetch_by_identifier($fid);
        }
        else {
          foreach my $f (@$t_features) {
            next unless $f;
            $f->{'_id_'} = $fid;
            push @$features, $f;
          }
        }
      }
    }
    return $features if $features && @$features; # Return if we have at least one feature

    # We have no features so return an error....
    unless ( $flag eq 'no_errors' ) {
      $self->problem( 'no_match', 'Invalid Identifier', "$object_type $id was not found" );
    }
    return undef;
  }

}

sub slice { return $_[0]->Obj; }

sub retrieve_features {
  my ($self, $features) = @_;
  my $method;
  my $results = [];  
  while (my ($type, $data) = each (%$features)) { 
    $method = 'retrieve_'.$type; 
    push @$results, [$self->$method($data,$type)] if defined &$method;
  }
  
  return $results;
}

sub retrieve_LRG {
  my ($self, $data, $type) = @_;
  my $results = [];
  foreach my $g (@$data) {
    if (ref($g) =~ /UnmappedObject/) {
      my $unmapped = $self->unmapped_object($g);
      push(@$results, $unmapped);
    }
    else {
      push @$results, {
        'region'   => $g->feature_Slice->seq_region_name,
        'start'    => $g->feature_Slice->start,
        'end'      => $g->feature_Slice->end,
        'strand'   => $g->feature_Slice->strand,
        'length'   => $g->end-$g->start+1,
        'extname'  => $g->stable_id,
        'label'    => $g->stable_id,
        'lrg_id'  => [ $g->stable_id ],
        'extra'    => [ $g->stable_id ]
      }
    }
  }

  return ( $results, ['Description'], $type );
}



sub _filename {
  my $self = shift;
  my $name = sprintf '%s-gene-%d-%s-%s',
	  $self->species,
	  $self->species_defs->ENSEMBL_VERSION,
	  $self->get_db,
	  $self->Obj->stable_id;
  $name =~ s/[^-\w\.]/_/g;
  return $name;
}

sub availability {
  my $self = shift;
  
  if (!$self->{'_availability'}) {
    my $availability = $self->_availability;
    my $obj = $self->Obj;
    my $counts = $self->counts();

    if ($self->Obj->isa('Bio::EnsEMBL::LRGSlice')) {
      my $rows = $self->table_info($self->get_db, 'stable_id_event')->{'rows'};
      my $funcgen_db = $self->database('funcgen');
      
      $availability->{'lrg'}        = 1;
      $availability->{'core'}       = $self->get_db eq 'core';
      $availability->{'regulation'} = $funcgen_db && $self->table_info('funcgen', 'feature_set')->{'rows'}; 
      $availability->{"has_$_"}     = $counts->{$_} for qw(structural_variation);
    }
    
    $self->{'_availability'} = $availability;
  }
  
  return $self->{'_availability'};
}

sub analysis {
  my $self = shift;
  return $self->builder->object('Gene')->analysis;
}

sub counts {
  my $self = shift;
  my $counts = $self->{'_counts'};

  $counts->{structural_variation} = 0;
  if ($self->database('variation')){
    my $vdb = $self->species_defs->get_config($self->species,'databases')->{'DATABASE_VARIATION'};
    $counts->{structural_variation} = $vdb->{'tables'}{'structural_variation'}{'rows'};
  }

  return $counts;

=pod
  my $obj = $self->Obj;

  return {} unless $obj->isa('Bio::EnsEMBL::Gene');
  
  my $key = "::COUNTS::GENE::$ENV{'ENSEMBL_SPECIES'}::$self->core_object('parameters')->{'db'}::$self->core_object('parameters')->{'lrg'}::";
  my $counts = $MEMD ? $MEMD->get($key) : undef;
  
  if (!$counts) {
    $counts = {
      transcripts         => scalar @{$obj->get_all_Transcripts},
      genes               => scalar @{$obj->get_all_Genes},
    }; 
    
    $MEMD->set($key, $counts, undef, 'COUNTS') if $MEMD;
  }
  
  return $counts;
=cut
}

sub count_xrefs {
  my $self = shift;
  my $type = $self->get_db;
  my $dbc = $self->database($type)->dbc;

  #xrefs on the gene
  my $xrefs_c = 0;
  my $sql = qq(
                SELECT x.display_label, edb.db_name, edb.status
                  FROM gene g, object_xref ox, xref x, external_db edb
                 WHERE g.gene_id = ox.ensembl_id
                   AND ox.xref_id = x.xref_id
                   AND x.external_db_id = edb.external_db_id
                   AND ox.ensembl_object_type = 'Gene'
                   AND g.gene_id = ?);
  my $sth = $dbc->prepare($sql);
  $sth->execute($self->Obj->dbID);
  while (my ($label,$db_name,$status) = $sth->fetchrow_array) {
    #these filters are taken directly from Component::_sort_similarity_links
    #code duplication needs removing, and some of these may well not be needed any more
    next if ($status eq 'ORTH');                        # remove all orthologs
    next if (lc($db_name) eq 'medline');                # ditch medline entries - redundant as we also have pubmed
    next if ($db_name =~ /^flybase/i && $type =~ /^CG/ ); # Ditch celera genes from FlyBase
    next if ($db_name eq 'Vega_gene');                  # remove internal links to self and transcripts
    next if ($db_name eq 'Vega_transcript');
    next if ($db_name eq 'Vega_translation');
    next if ($db_name eq 'GO');
    next if ($db_name eq 'OTTP') && $label =~ /^\d+$/; #ignore xrefs to vega translation_ids
    $xrefs_c++;
  }
  return $xrefs_c;
}

sub count_gene_supporting_evidence {
  #count all supporting_features and transcript_supporting_features for the gene
  #- not used in the tree but keep the code just in case we change our minds again!
  my $self = shift;
  my $obj = $self->Obj;
  my $o_type = $self->get_db;
  my $evi_count = 0;
  my %c;
  foreach my $trans (@{$obj->get_all_Transcripts()}) {
    foreach my $evi (@{$trans->get_all_supporting_features}) {
      my $hit_name = $evi->hseqname;
      $c{$hit_name}++;
    }
    foreach my $exon (@{$trans->get_all_Exons()}) {
      foreach my $evi (@{$exon->get_all_supporting_features}) {
	my $hit_name = $evi->hseqname;
	$c{$hit_name}++;
      }
    }
  }
  return scalar(keys(%c));
}


##vega
sub count_self_alignments {
  my $self = shift;
  my $species = $self->species; 
  my $object   = $self->Obj;
  my $sd = $self->species_defs;

  ## Get the compara database hash!
  my $hash = $sd->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'};
  my $matches = $hash->{'BLASTZ_RAW'}->{$species};

  ## Get details of the primary slice
  my $ps_name  = $object->seq_region_name;
  my $ps_start = $object->seq_region_start;
  my $ps_end   = $object->seq_region_end;

  ## Identify alignments that match the primary slice
  my $matching = 0;
  foreach my $other_species (sort keys %{$matches}) {
    foreach my $alignment (keys %{$matches->{$other_species}}) {
      my $this_name = $matches->{$other_species}{$alignment}{'source_name'};
      #only use alignments that include the primary slice
      next unless ($ps_name eq $this_name);
      my $start = $matches->{$other_species}{$alignment}{'source_start'};
      my $end = $matches->{$other_species}{$alignment}{'source_end'};
      #only create entries for alignments that overlap the current slice
      if ($end > $ps_start && $start < $ps_end) {
	$matching++;
      }
    }
  }
  return $matching;
}

##vega
sub check_compara_species_and_locations {
  #check if genomic_alignments and or orthologues of this gene would have been found
  my $self = shift;
  my $species = $self->species;
  my $sd = $self->species_defs;
  my $hash = $sd->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'};
  return 0 unless $hash;
  unless ($hash->{'BLASTZ_RAW'}{$species}) {
    return 0; #if this species is not in compara
  }
  my $regions  = $hash->{'REGION_SUMMARY'}{$species};
  my $object   = $self->Obj;
  my $sr_name  = $object->seq_region_name;
  unless ($regions->{$sr_name}) {
    return 0; #if this seq_region is not in compara
  }
  my $sr_start = $object->seq_region_start;
  my $sr_end   = $object->seq_region_end;
  my $matching = 0;
  foreach my $compara_region (@{$regions->{$sr_name}}) {
    if ( ($sr_start < $compara_region->{'end'}) && ($sr_end > $compara_region->{'start'}) ) {
      $matching = 1; #if the gene overlaps the region in compara
    }
  }
  return $matching;
}

sub get_external_dbs {
  #retrieve a summary of the external_db table from species defs
  my $self = shift;
  my $db   = $self->get_db;
  my $db_type = 'DATABASE_'.uc($db);
  my $sd = $self->species_defs;
  return  $sd->databases->{$db_type}{'external_dbs'};
}

sub get_gene_supporting_evidence {
  #get supporting evidence for the gene: transcript_supporting_features support the
  #whole transcript or the translation, supporting_features provide depth the the evidence
  my $self    = shift;
  my $obj     = $self->Obj;
  my $species = $self->species;
  my $ln      = $self->logic_name;
  my $dbentry_adap = Bio::EnsEMBL::Registry->get_adaptor($species, "core", "DBEntry");
  my $o_type  = $self->get_db;
  my $e;
  foreach my $trans (@{$obj->get_all_Transcripts()}) {
    my $tsi = $trans->stable_id;
    my %t_hits;
    my %vega_evi;
  EVI:
    foreach my $evi (@{$trans->get_all_supporting_features}) {
      my $name = $evi->hseqname;
      my $db_name = $dbentry_adap->get_db_name_from_external_db_id($evi->external_db_id);
      #save details of evidence for vega genes for later since we need to combine them 
      #before we can tellif they match the CDS / UTR 
      if ($ln =~ /otter/) {
	push @{$vega_evi{$name}{'data'}}, $evi;
	$vega_evi{$name}->{'db_name'} = $db_name;
	$vega_evi{$name}->{'evi_type'} = ref($evi);
	next EVI;
      }

      #for e! genes...
      #use coordinates to check if the transcript evidence supports the CDS, UTR, or just the transcript
      #for protein features give some leeway in matching to transcript - +- 3 bases
      if ($evi->isa('Bio::EnsEMBL::DnaPepAlignFeature')) {
	if (   (abs($trans->coding_region_start-$evi->seq_region_start) < 4)
		 || (abs($trans->coding_region_end-$evi->seq_region_end) < 4)) {
	  $e->{$tsi}{'evidence'}{'CDS'}{$name} = $db_name;
	  $t_hits{$name}++;
	}
	else {
	  $e->{$tsi}{'evidence'}{'UNKNOWN'}{$name} = $db_name;
	  $t_hits{$name}++;
	}
      }
      elsif ( $trans->coding_region_start == $evi->seq_region_start
		|| $trans->coding_region_end == $evi->seq_region_end ) {
	$e->{$tsi}{'evidence'}{'CDS'}{$name} = $db_name;
	$t_hits{$name}++;
      }

      elsif ( $trans->seq_region_start  == $evi->seq_region_start
		|| $trans->seq_region_end == $evi->seq_region_end ) {
	$e->{$tsi}{'evidence'}{'UTR'}{$name} = $db_name;
	$t_hits{$name}++;
      }
      else {
	$e->{$tsi}{'evidence'}{'UNKNOWN'}{$name} = $db_name;
	$t_hits{$name}++;
      }
    }
    $e->{$tsi}{'logic_name'} = $trans->analysis->logic_name;

    #make a note of the hit_names of the supporting_features (but don't bother for vega db genes)
    if ($ln !~ /otter/) {
      foreach my $exon (@{$trans->get_all_Exons()}) {
	foreach my $evi (@{$exon->get_all_supporting_features}) {
	  my $hit_name = $evi->hseqname;
	  if (! exists($t_hits{$hit_name})) {
	    $e->{$tsi}{'extra_evidence'}{$hit_name}++;
	  }
	}
      }
    }

    #look at vega evidence to see if it can be assigned to 'CDS' 'UTR' etc
    while ( my ($hit_name,$rec) = each %vega_evi ) {
      my ($min_start,$max_end) = (1e8,1);
      my $db_name  = $rec->{'db_name'};
      my $evi_type = $rec->{'evi_type'};
      foreach my $hit (@{$rec->{'data'}}) {
	$min_start = $hit->seq_region_start <= $min_start ? $hit->seq_region_start : $min_start;
	$max_end   = $hit->seq_region_end   >= $max_end   ? $hit->seq_region_end   : $max_end;
      }
      if ($evi_type eq 'Bio::EnsEMBL::DnaPepAlignFeature') {
	#protein evidence supports CDS
	$e->{$tsi}{'evidence'}{'CDS'}{$hit_name} = $db_name;
      }
      else {
	if ($min_start < $trans->coding_region_start && $max_end > $trans->coding_region_end) {
	  #full length DNA evidence supports CDS
	  $e->{$tsi}{'evidence'}{'CDS'}{$hit_name} = $db_name;
	}
	if (  $max_end   < $trans->coding_region_start
	   || $min_start > $trans->coding_region_end
	   || $trans->seq_region_start  == $min_start
           || $trans->seq_region_end    == $max_end ) {
	  #full length DNA evidence or that exclusively in the UTR supports the UTR
	  $e->{$tsi}{'evidence'}{'UTR'}{$hit_name} = $db_name;
	}
	elsif (! $e->{$tsi}{'evidence'}{'CDS'}{$hit_name}) {
	  $e->{$tsi}{'evidence'}{'UNKNOWN'}{$hit_name} = $db_name;
	}
      }
    }
  }
  return $e;
}

#generate URLs for evidence links
sub add_evidence_links {
  my $self = shift;
  my $ids  = shift;
  my $links = [];
  foreach my $hit_name (sort keys %$ids) {
    my $db_name = $ids->{$hit_name};
    my $display = $self->hub->get_ExtURL_link( $hit_name, $db_name, $hit_name );
    push @{$links}, [$display,$hit_name];
  }
  return $links;
}

sub get_slice_object {
  my $self = shift;
  my $slice = $self->Obj->feature_Slice->expand( $self->param('flank5_display'), $self->param('flank3_display') );
  return 1 unless $slice;
  my $T = $self->new_object( 'Slice', $slice, $self->__data );
  #  $T->highlight_display( $self->Obj->get_all_Exons );
  return $T;
}

sub get_Slice {
  my ($self, $context, $ori) = @_;
  
  my @genes = @{$self->Obj->get_all_Genes('LRG_import')||[]};
  my $slice = $genes[0]->feature_Slice;

  if ($context =~ /(\d+)%/) {
    $context = $slice->length * $1 / 100;
  }
  
  $slice = $slice->invert if $ori && $slice->strand != $ori;
  
  return $slice->expand($context, $context);
}


sub lrg_name {
  my $self = shift;
  return  $self->stable_id;
}
sub lrg_short_caption {
  my $self = shift;
  
  
}

sub short_caption {
  my $self = shift;
  return 'LRG-based displays' unless shift eq 'global';

  my $label = $self->Obj->stable_id;
  return "LRG: $label";
}

sub caption {
  my $self = shift;
  my $heading = $self->type_name.': ';
  my $subhead;

  my( $disp_id ) = $self->display_xref;
  if( $disp_id && $disp_id ne $self->stable_id ) {
    $heading .= $disp_id;
    $subhead = $self->stable_id;
  }
  else {
    $heading .= $self->stable_id;
  }

  return [$heading, $subhead];
}

sub type_name         { return 'LRG';                                         }
sub stable_id         { return $_[0]->Obj->stable_id;                         }
sub feature_type      { return $_[0]->Obj->type;                              }
sub source            { return $_[0]->Obj->source;                            }
sub version           { return $_[0]->Obj->version;                           }
sub logic_name        { return $_[0]->Obj->analysis->logic_name;              }
sub coord_system      { return $_[0]->Obj->feature_Slice->coord_system->name; }
sub seq_region_type   { return $_[0]->coord_system;                           }
sub seq_region_name   { return $_[0]->Obj->feature_Slice->seq_region_name;    }
sub seq_region_start  { return $_[0]->Obj->feature_Slice->start;              }
sub seq_region_end    { return $_[0]->Obj->feature_Slice->end;                }
sub seq_region_strand { return $_[0]->Obj->feature_Slice->strand;             }
sub feature_length    { return $_[0]->Obj->feature_Slice->length;             }

sub gene {
  my $self = shift;
  $self->__data->{'gene'} = @{$self->Obj->get_all_Genes || []}[0] unless $self->__data->{'gene'};
  return $self->__data->{'gene'};
}

sub transcript {
  my $self = shift;
  $self->__data->{'transcript'} = @{$self->Obj->get_all_Transcripts(undef, 'LRG_import') || []}[0] unless $self->__data->{'transcript'};
  return $self->__data->{'transcript'};
}

sub get_external_id {
  my( $self, $type ) = @_; 
  my $links = $self->get_database_matches($self->gene);
  my $ext_id;
  foreach my $link (@$links) {
    $ext_id = $link->primary_id if ($link->database eq $type);
  }
  return $ext_id;
}

sub get_database_matches {
  my $self = shift;
  my @DBLINKS;
  eval { @DBLINKS = @{$self->Obj->get_all_DBLinks};};
  return \@DBLINKS  || [];
}

sub get_all_transcripts {
  my $self = shift;
  
  if (!$self->{'data'}{'_transcripts'}) {
    foreach (@{$self->Obj->get_all_Transcripts(undef, 'lrg_import')||[]}){
      my $transcript = $self->new_object('Transcript', $_, $self->__data);
      $transcript->gene($self->gene);
      push @{$self->{'data'}{'_transcripts'}}, $transcript;
    }
  }
  
  return $self->{'data'}{'_transcripts'};
}


sub get_all_families {
  my $self = shift;
  my $families;
  if (ref($self->gene) =~ /Family/) { ## No gene in URL, so CoreObjects fetches a family instead
    ## Explicitly set db connection, as registry is buggy!
    my $family = $self->gene;
    my $dba = $self->database('core', $self->species);
    my $genome_db = Bio::EnsEMBL::Compara::GenomeDB->new();
    $genome_db->db_adaptor( $dba );
    my $members = $family->get_all_Members;
    my $info = {'description' => $family->description};
    my $genes = [];
    foreach my $member (@$members) {
      $member->genome_db($genome_db);
      my $gene = $member->get_Gene;
      push @$genes, $gene if $gene;
    }
    $info->{'genes'} = $genes;
    $info->{'count'} = @$genes;
    $families->{$self->param('family')} = {'info' => $info};
  }
  else {
    foreach my $transcript (@{$self->get_all_transcripts}) {
      my $trans_families = $transcript->get_families;
      while (my ($id, $info) = each (%$trans_families)) {
        if (exists $families->{$id}) {
          push @{$families->{$id}{'transcripts'}}, $transcript;
        }
        else {
          my @A = keys %$info;
          warn "INFO @A";
          $families->{$id} = {'info' => $info, 'transcripts' => [$transcript]};
        }
      }
    }
  }
  return $families;
}

sub create_family {
  my ($self, $id) = @_; 
  my $databases = $self->database('compara') ;
  my $family_adaptor;
  eval{ $family_adaptor = $databases->get_FamilyAdaptor };
  if ($@){ warn($@); return {} }
  return $family_adaptor->fetch_by_stable_id($id);
}

sub chromosome {
  my $self = shift;
  return undef if lc($self->coord_system) ne 'chromosome';
  return $self->Obj->slice->seq_region_name;
}

sub display_xref {
  my $self = shift;
  my $obj  = $self->Obj;
  return $obj->isa('Bio::EnsEMBL::Compara::Family') || $obj->isa('Bio::EnsEMBL::ArchiveStableId') ? undef : $obj->display_xref;
}

sub mod_date {
  my $self = shift;
  my $time = $self->gene()->modified_date;
  return $self->date_format( $time,'%d/%m/%y' ), $self->date_format( $time, '%y/%m/%d' );
}

sub created_date {
  my $self = shift;
  my $time = $self->gene()->created_date;
  return $self->date_format( $time,'%d/%m/%y' ), $self->date_format( $time, '%y/%m/%d' );
}

sub get_author_name {
    my $self = shift;
    my $attribs = $self->Obj->get_all_Attributes('author');
    if (@$attribs) {
        return $attribs->[0]->value;
    } else {
        return undef;
    }
}

sub gene_type {
  my $self = shift;
  my $db = $self->get_db;
  my $type = '';
  if( $db eq 'core' ){
    $type = ucfirst($self->Obj->biotype);
    $type =~ s/_/ /g;
    $type ||= $self->db_type;
  } elsif ($db eq 'vega') {
    my $biotype = ($self->Obj->biotype eq 'tec') ? uc($self->Obj->biotype) : ucfirst(lc($self->Obj->biotype));
    $type = ucfirst($biotype);
    $type =~ s/_/ /g;
    $type =~ s/unknown //i;
    return $type;
  } else {
    $type = $self->logic_name;
  }
  $type ||= $db;
  if( $type !~ /[A-Z]/ ){ $type = ucfirst($type) } #All lc, so format
  return $type;
}

sub date_format {
  my( $self, $time, $format ) = @_;
  my( $d,$m,$y) = (localtime($time))[3,4,5];
  my %S = ('d'=>sprintf('%02d',$d),'m'=>sprintf('%02d',$m+1),'y'=>$y+1900);
  (my $res = $format ) =~s/%(\w)/$S{$1}/ge;
  return $res;
}

sub location_string {
  my $self = shift;
  return sprintf( "%s:%s-%s", $self->seq_region_name, $self->seq_region_start, $self->seq_region_end );
}

sub get_contig_location {
  my $self    = shift;
  my ($pr_seg) = @{$self->Obj->project('seqlevel')};
  return undef unless $pr_seg;
  return (
    $self->neat_sr_name( $pr_seg->[2]->coord_system->name, $pr_seg->[2]->seq_region_name ),
    $pr_seg->[2]->seq_region_name,
    $pr_seg->[2]->start
  );
}

sub get_alternative_locations {
  my $self = shift;
  my @alt_locs = map { [ $_->slice->seq_region_name, $_->start, $_->end, $_->slice->coord_system->name ] }
     @{$self->Obj->get_all_alt_locations};
  return \@alt_locs;
}

sub get_homology_matches {
  my ($self, $homology_source, $homology_description, $disallowed_homology, $geneid, $compara_db) = @_;
  
  $homology_source      ||= 'ENSEMBL_HOMOLOGUES';
  $homology_description ||= 'ortholog';
  $compara_db           ||= 'compara';
  
  my $key = "$homology_source::$homology_description";
  
  if (!$self->{'homology_matches'}{$key}) {
    my $homologues = $self->fetch_homology_species_hash($homology_source, $homology_description, $geneid, $compara_db);

    return $self->{'homology_matches'}{$key} = {} unless keys %$homologues;
    
    my $adaptor_call  = $self->param('gene_adaptor') || 'get_GeneAdaptor';
    my %homology_list;

    foreach my $display_spp (keys %$homologues){
      my $order = 0;
      
      foreach my $homology (@{$homologues->{$display_spp}}){ 
        my ($homologue, $homology_desc, $query_perc_id, $target_perc_id, $dnds_ratio, $gene_tree_node_id, $homology_id) = @$homology;
        next unless $homology_desc =~ /$homology_description/;
        next if $disallowed_homology && $homology_desc =~ /$disallowed_homology/;
        
# Avoid displaying duplicated (within-species and other paralogs) entries in the homology table (e!59). Skip the other_paralog (     or overwrite it)
        next if $homology_list{$display_spp}{$homologue->stable_id} && $homology_desc eq 'other_paralog';
 
        $homology_list{$display_spp}{$homologue->stable_id} = {
          homology_desc       => $Bio::EnsEMBL::Compara::Homology::PLAIN_TEXT_WEB_DESCRIPTIONS{$homology_desc} || 'no description',
          description         => $homologue->description       || 'No description',
          display_id          => $homologue->display_label     || 'Novel Ensembl prediction',
          spp                 => $display_spp,
          query_perc_id       => $query_perc_id,
          target_perc_id      => $target_perc_id,
          homology_dnds_ratio => $dnds_ratio,
          gene_tree_node_id   => $gene_tree_node_id,
          dbID                => $homology_id,
          order               => $order,
          location            => sprintf('%s:%s-%s:%s', $homologue->dnafrag()->name, map $homologue->$_, qw(dnafrag_start dnafrag_end dnafrag_strand))
        };

        $order++;
      }
    }
    
    $self->{'homology_matches'}{$key} = \%homology_list;
  }
  
  return $self->{'homology_matches'}{$key};
}

sub fetch_homology_species_hash {
  my $self = shift;
  my $homology_source = shift;
  my $homology_description = shift;
  my $geneid = shift;
  my $compara_db = shift || 'compara';
  
  $homology_source = "ENSEMBL_HOMOLOGUES" unless (defined $homology_source);
  $homology_description= "ortholog" unless (defined $homology_description);
  
  my $database = $self->database($compara_db) ;
  my %homologues;

  return {} unless $database;

  my $query_member = $database->get_GeneMemberAdaptor->fetch_by_stable_id($geneid);

  return {} unless defined $query_member ;

  my $homology_adaptor = $database->get_HomologyAdaptor;
#  It is faster to get all the Homologues and discard undesired entries
#  my $homologies_array = $homology_adaptor->fetch_all_by_Member_method_link_type($query_member,$homology_source);
  my $homologies_array = $homology_adaptor->fetch_all_by_Member($query_member);

  # Strategy: get the root node (this method gets the whole lineage without getting sister nodes)
  # We use right - left indexes to get the order in the hierarchy.
  
  my %classification = ( Undetermined => 99999999 );

  if (my $taxon = $query_member->taxon) {
    my $node = $taxon->root();

    while ($node){
      $node->get_tagvalue('scientific name');
      # Found a speed boost with nytprof -- avilella
      # $classification{$node->get_tagvalue('scientific name')} = $node->right_index - $node->left_index;
      $classification{$node->{_tags}{'scientific name'}} = $node->{_right_index} - $node->{_left_index};
      $node = $node->children->[0];
    }
  }

  foreach my $homology (@$homologies_array) {
    next unless $homology->description =~ /$homology_description/;

    my ($query_perc_id, $target_perc_id, $genome_db_name, $target_member, $dnds_ratio);

    foreach my $member (@{$homology->get_all_Members}) {
      my $gene_member = $member->gene_member;

      if ($gene_member->stable_id eq $query_member->stable_id) {
        $query_perc_id = $member->perc_id;
      } else {
        $target_perc_id = $member->perc_id;
        $genome_db_name = $member->genome_db->name;
        $target_member  = $gene_member;
        $dnds_ratio     = $homology->dnds_ratio;
      }
    }

    # FIXME: ucfirst $genome_db_name is a hack to get species names right for the links in the orthologue/paralogue tables.
    # There should be a way of retrieving this name correctly instead.
    push @{$homologues{ucfirst $genome_db_name}}, [ $target_member, $homology->description, $query_perc_id, $target_perc_id, $dnds_ratio, $homology->{_gene_tree_node_id}, $homology->dbID ];
  }

  @{$homologues{$_}} = sort { $classification{$a->[2]} <=> $classification{$b->[2]} } @{$homologues{$_}} for keys %homologues;

  return \%homologues;
}


sub get_disease_matches{
  my $self = shift;
  my %disease_list;
  my $disease_adaptor;
  return undef unless ($disease_adaptor = $self->database('disease'));
  my %omim_disease = ();
  my @diseases = $disease_adaptor->disease_name_by_ensembl_gene($self->gene());
  foreach my $disease (@diseases){
    next unless $disease;
    my $desc = $disease->name;
    foreach my $loc ($disease->each_Location){
      my $omim_id = $loc->db_id;
      push @{$omim_disease{$desc}}, $omim_id;
    }
  }
  return \%omim_disease ;
}

sub get_compara_Member{
  # Returns the Bio::EnsEMBL::Compara::Member object
  # corresponding to this gene 
  my $self = shift;
  my $compara_db = shift || 'compara';

  # Catch coderef
  my $cachekey = "_compara_member_$compara_db";
  my $error = sub{ warn($_[0]); $self->{$cachekey}=0; return 0};

  unless( defined( $self->{$cachekey} ) ){ # Look in cache
    # Prepare the adaptors
    my $compara_dba = $self->database( $compara_db )           || &$error( "No compara db" );
    my $genemember_adaptor = $compara_dba->get_adaptor('GeneMember') || &$error( "Cannot COMPARA->get_adaptor('GeneMember')" );
    # Fetch the object
    my $id = $self->stable_id;
    my $member = $genemember_adaptor->fetch_by_stable_id($id) || &$error( "<h3>No compara ENSEMBLGENE member for $id</h3>" );
    # Update the cache
    $self->{$cachekey} = $member;
  }
  # Return cached value
  return $self->{$cachekey};
}

sub get_ProteinTree {
  # deprecated, use get_GeneTree
  return get_GeneTree(@_);
}

sub get_GeneTree {
  # Returns the Bio::EnsEMBL::Compara::ProteinTree object
  # corresponding to this gene
  my $self = shift;
  my $compara_db = shift || 'compara';

  # Where to keep the cached data
  my $cachekey = "_protein_tree_$compara_db";

  # Catch coderef
  my $error = sub{ warn($_[0]); $self->{$cachekey}=0; return 0};

  unless( defined( $self->{$cachekey} ) ){ # Look in cache
    # Fetch the objects
    my $member = $self->get_compara_Member($compara_db)
        || &$error( "No compara member for this gene" );
    my $tree_adaptor = $member->adaptor->db->get_adaptor('GeneTree')
        || &$error( "Cannot COMPARA->get_adaptor('GeneTree')" );
    my $tree = $tree_adaptor->fetch_all_by_Member($member, -clusterset_id => 'default');
    $tree = $tree->[0]->root
        || &$error( "No compara tree for ENSEMBLGENE $member" );
    # Update the cache
    $self->{$cachekey} = $tree;
  }
  # Return cached value
  return $self->{$cachekey};
}

#----------------------------------------------------------------------

sub get_gene_slices {
  my ($self, $master_config, @slice_configs) = @_;
  
  foreach my $array (@slice_configs) { 
    if ($array->[1] eq 'normal') {
      my $slice = $self->get_Slice($array->[2], 1); 
      $self->__data->{'slices'}{$array->[0]} = [ 'normal', $slice, [], $slice->length ];
    } else { 
      $self->__data->{'slices'}{$array->[0]} = $self->get_munged_slice($master_config, $array->[2], 1);
    }
  }
}

# Calls for HistoryView

sub get_archive_object {
  my $self = shift;
  my $id = $self->stable_id;
  my $archive_adaptor = $self->database('core')->get_ArchiveStableIdAdaptor;
  my $archive_object = $archive_adaptor->fetch_by_stable_id($id);

 return $archive_object;
}

sub get_latest_incarnation {
  my $self = shift;
  return $self->Obj->get_latest_incarnation;
}

=head2 get_all_associated_archived

 Arg1        : data object
 Description : fetches all associated archived IDs
 Return type : Arrayref of
                  Bio::EnsEMBL::ArchiveStableId archived gene
                  Bio::EnsEMBL::ArchiveStableId archived transcript
                  Bio::EnsEMBL::ArchiveStableId archived translation (optional)
                  String peptide sequence (optional)

=cut

sub get_all_associated_archived {
  my $self = shift;
  return $self->Obj->get_all_associated_archived;
}


=head2 history

 Arg1        : data object
 Description : gets the archive id history tree based around this ID
 Return type : listref of Bio::EnsEMBL::ArchiveStableId
               As every ArchiveStableId knows about it's successors, this is
                a linked tree.

=cut

sub history {
  my $self = shift;
  
  my $archive_adaptor = $self->database('core')->get_ArchiveStableIdAdaptor;
  return unless $archive_adaptor;

  my $history = $archive_adaptor->fetch_history_tree_by_stable_id($self->stable_id);
  return $history;
}


# Calls for GeneRegulationView 

sub get_fg_db {
  my $self = shift;
  my $slice = $self->get_Slice( @_ );
  my $fg_db = undef;
  my $db_type  = 'funcgen';
  unless($slice->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice")) {
    $fg_db = $slice->adaptor->db->get_db_adaptor($db_type);
    if(!$fg_db) {
      warn("Cannot connect to $db_type db");
      return [];
    }
  }
return $fg_db;
}

sub feature_sets {
  my $self = shift;

  my $available_sets = [];
  if ( $self->species_defs->databases->{'DATABASE_FUNCGEN'} ) {
    $available_sets = $self->species_defs->databases->{'DATABASE_FUNCGEN'}->{'FEATURE_SETS'};
  }
  my $fg_db = $self->get_fg_db; 
  my $feature_set_adaptor = $fg_db->get_FeatureSetAdaptor;
  my @fsets;

  foreach my $name ( @$available_sets){ 
    push @fsets, $feature_set_adaptor->fetch_by_name($name);
  } 
  return \@fsets; 
}



sub reg_factors {
  my $self = shift;
  my $gene = $self->gene;  
  my $fsets = $self->feature_sets;
  my $fg_db= $self->get_fg_db; 
  my $ext_feat_adaptor = $fg_db->get_ExternalFeatureAdaptor; 
  my $factors = $ext_feat_adaptor->fetch_all_by_Gene_FeatureSets($gene, $fsets, 1);
 
 return $factors;   
}

sub reg_features {
  my $self = shift; 
  my $gene = $self->gene;
  my $fg_db= $self->get_fg_db; 
  my $slice = $self->get_Slice( @_ );

  my $reg_feat_adaptor = $fg_db->get_RegulatoryFeatureAdaptor; 
  my $feats = $reg_feat_adaptor->fetch_all_by_Slice($slice);
  return $feats;

}

=head2 vega_projection

 Arg[1]       : Alternative assembly name
 Example     : my $v_slices = $object->ensembl_projection($alt_assembly)
 Description : map an object to an alternative (vega) assembly
 Return type : arrayref

=cut

sub vega_projection {
  my $self = shift;
  my $alt_assembly = shift;
  my $alt_projection = $self->Obj->feature_Slice->project('chromosome', $alt_assembly);
  my @alt_slices = ();
  foreach my $seg (@{ $alt_projection }) {
    my $alt_slice = $seg->to_Slice;
    push @alt_slices, $alt_slice;
  }
  return \@alt_slices;
}

=head2 get_similarity_hash

 Arg[1]      : none
 Example     : $similarity_matches = $webobj->get_similarity_hash
 Description : Returns an arrayref of hashes containing similarity matches
 Return type : an array ref

=cut

sub get_similarity_hash {
  my $self = shift;
  my $DBLINKS;
  eval { $DBLINKS = $self->Obj->get_all_DBEntries; };
  warn ("SIMILARITY_MATCHES Error on retrieving gene DB links $@") if ($@);
  return $DBLINKS  || [];
}

sub can_export {
  my $self = shift;
  return $self->action =~ /^(Export|Genome|Sequence_DNA)$/ ? 0 : $self->availability->{'lrg'};
}

1;

