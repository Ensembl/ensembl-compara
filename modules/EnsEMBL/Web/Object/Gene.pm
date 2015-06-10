=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Object::Gene;

### NAME: EnsEMBL::Web::Object::Gene
### Wrapper around a Bio::EnsEMBL::Gene object

### PLUGGABLE: Yes, using Proxy::Object 

### STATUS: At Risk
### Contains a lot of functionality not directly related to
### manipulation of the underlying API object 

### DESCRIPTION

use strict;

use EnsEMBL::Web::Constants; 
use EnsEMBL::Web::Cache;
use Bio::EnsEMBL::Compara::Homology;

use Time::HiRes qw(time);

use base qw(EnsEMBL::Web::Object);

our $MEMD = EnsEMBL::Web::Cache->new;

sub availability {
  my $self = shift;
  my ($database_synonym) = @_;
  
  if (!$self->{'_availability'}) {
    my $availability = $self->_availability;
    my $obj = $self->Obj;
    
    if ($obj->isa('Bio::EnsEMBL::ArchiveStableId')) {
      $availability->{'history'} = 1;
    } elsif ($obj->isa('Bio::EnsEMBL::Gene')) {
      my $member      = $self->database('compara') ? $self->database('compara')->get_GeneMemberAdaptor->fetch_by_stable_id($obj->stable_id) : undef;
      my $pan_member  = $self->database('compara_pan_ensembl') ? $self->database('compara_pan_ensembl')->get_GeneMemberAdaptor->fetch_by_stable_id($obj->stable_id) : undef;
      my $counts      = $self->counts($member, $pan_member);
      my $rows        = $self->table_info($self->get_db, 'stable_id_event')->{'rows'};
      my $funcgen_res = $self->database('funcgen') ? $self->table_info('funcgen', 'feature_set')->{'rows'} ? 1 : 0 : 0;

      $availability->{'history'}              = !!$rows;
      $availability->{'gene'}                 = 1;
      $availability->{'core'}                 = $self->get_db eq 'core';
      $availability->{'has_gene_tree'}        = $member ? $member->has_GeneTree : 0;
      $availability->{'can_r2r'}              = $self->hub->species_defs->R2R_BIN;
      if ($availability->{'can_r2r'}) {
        my $tree = $availability->{'has_gene_tree'} ? $self->database('compara')->get_GeneTreeAdaptor->fetch_default_for_Member($member) : undef;
        $availability->{'has_2ndary_cons'}    = $tree && $tree->get_tagvalue('ss_cons') ? 1 : 0;
        $availability->{'has_2ndary'}         = ($availability->{'has_2ndary_cons'} || ($obj->canonical_transcript && scalar(@{$obj->canonical_transcript->get_all_Attributes('ncRNA')}))) ? 1 : 0;
      }
      $availability->{'has_gxa'}              = $self->gxa_check;

      $availability->{'alt_allele'}           = $self->table_info($self->get_db, 'alt_allele')->{'rows'};
      $availability->{'regulation'}           = !!$funcgen_res; 
      $availability->{'has_species_tree'}     = $member ? $member->has_GeneGainLossTree : 0;
      $availability->{'family'}               = !!$counts->{families};
      $availability->{'family_count'}         = $counts->{families};
      $availability->{'not_rnaseq'}           = $self->get_db eq 'rnaseq' ? 0 : 1;
      $availability->{"has_$_"}               = $counts->{$_} for qw(transcripts alignments paralogs orthologs similarity_matches operons structural_variation pairwise_alignments);
      $availability->{'multiple_transcripts'} = $counts->{'transcripts'} > 1;
      $availability->{'not_patch'}            = $obj->stable_id =~ /^ASMPATCH/ ? 0 : 1; ## TODO - hack - may need rewriting for subsequent releases
      $availability->{'has_alt_alleles'} =  scalar @{$self->get_alt_alleles};
      
      if ($self->database('variation')) {
        $availability->{'has_phenotypes'} = $self->get_phenotype;
      }

      if ($self->database('compara_pan_ensembl')) {
        $availability->{'family_pan_ensembl'} = !!$counts->{families_pan};
        $availability->{'has_gene_tree_pan'}  = !!($pan_member && $pan_member->has_GeneTree);
        $availability->{"has_$_"}             = $counts->{$_} for qw(alignments_pan paralogs_pan orthologs_pan);
      }
    } elsif ($obj->isa('Bio::EnsEMBL::Compara::Family')) {
      $availability->{'family'} = 1;
    }
    $self->{'_availability'} = $availability;
  }

  return $self->{'_availability'};
}

sub analysis {
  my $self = shift;
  return $self->Obj->analysis;
}

sub default_action { return $_[0]->Obj->isa('Bio::EnsEMBL::ArchiveStableId') ? 'Idhistory' : $_[0]->Obj->isa('Bio::EnsEMBL::Compara::Family') ? 'Family' : 'Summary'; }

sub counts {
  my ($self, $member, $pan_member) = @_;
  my $obj = $self->Obj;

  return {} unless $obj->isa('Bio::EnsEMBL::Gene');
  
  my $key = sprintf '::COUNTS::GENE::%s::%s::%s::', $self->species, $self->hub->core_param('db'), $self->hub->core_param('g');
  my $counts = $self->{'_counts'};
  $counts ||= $MEMD->get($key) if $MEMD;
  
  if (!$counts) {
    $counts = {
      transcripts        => scalar @{$obj->get_all_Transcripts},
      exons              => scalar @{$obj->get_all_Exons},
#      similarity_matches => $self->count_xrefs
      similarity_matches => $self->get_xref_available,
      operons => 0,
      alternative_alleles =>  scalar @{$self->get_alt_alleles},
    };
    if ($obj->feature_Slice->can('get_all_Operons')){
      $counts->{'operons'} = scalar @{$obj->feature_Slice->get_all_Operons};
    }
    $counts->{structural_variation} = 0;

    if ($self->database('variation')){ 
      my $vdb = $self->species_defs->get_config($self->species,'databases')->{'DATABASE_VARIATION'};
      $counts->{structural_variation} = $vdb->{'tables'}{'structural_variation'}{'rows'};
      $counts->{phenotypes} = $self->get_phenotype;
    }
    if ($member) {
      $counts->{'orthologs'}  = $member->number_of_orthologues;
      $counts->{'paralogs'}   = $member->number_of_paralogues;
      $counts->{'families'}   = $member->number_of_families;
    }
    my $alignments = $self->count_alignments;
    $counts->{'alignments'} = $alignments->{'all'} if $self->get_db eq 'core';
    $counts->{'pairwise_alignments'} = $alignments->{'pairwise'} + $alignments->{'patch'};

    ## Add pan-compara if available 
    if ($pan_member) {
      my $compara_dbh = $self->database('compara_pan_ensembl')->dbc->db_handle;

      $counts->{'orthologs_pan'}  = $pan_member->number_of_orthologues;
      $counts->{'paralogs_pan'}   = $pan_member->number_of_paralogues;
      $counts->{'families_pan'}   = $pan_member->number_of_families;

      $counts->{'alignments_pan'} = $self->count_alignments('DATABASE_COMPARA_PAN_ENSEMBL')->{'all'} if $self->get_db eq 'core';
    }    

    ## Add counts from plugins
    $counts = {%$counts, %{$self->_counts($member, $pan_member)}};

    $MEMD->set($key, $counts, undef, 'COUNTS') if $MEMD;
    $self->{'_counts'} = $counts;
  }
  
  return $counts;
}
sub get_phenotype {
  my $self = shift;
  
  my $phen_count  = 0;
  my $pfa         = Bio::EnsEMBL::Registry->get_adaptor($self->species, 'variation', 'PhenotypeFeature');
  $phen_count     = $pfa->count_all_by_Gene($self->Obj);

  if (!$phen_count) {
    my $hgncs = $self->Obj->get_all_DBEntries('hgnc') || [];

    if(scalar @$hgncs && $hgncs->[0]) {
      my $hgnc_name = $hgncs->[0]->display_id;
      $phen_count   = $pfa->_check_gene_by_HGNC($hgnc_name) if $hgnc_name; # this method is super-fast as it uses some direct SQL on a nicely indexed table
    }
  }
  
  return $phen_count;
}
sub get_xref_available{
  my $self=shift;
  my $available = ($self->count_xrefs > 0);
  if(!$available){
    my @my_transcripts= @{$self->Obj->get_all_Transcripts};
    my @db_links;
    for (my $i=0; !$available && ($i< scalar @my_transcripts); $i++) {
      eval { 
        @db_links = @{$my_transcripts[$i]->get_all_DBLinks};
      };
            
      for (my $j=0; !$available && ($j< scalar @db_links); $j++) {
        $available = $available || ($db_links[$j]->type eq 'MISC') || ($db_links[$j]->type eq 'LIT');
      }      
    }
  }
  return $available;
}


sub _insdc_synonym {
  my ($self,$slice,$name) = @_;

  my $dbc = $self->database($self->get_db)->dbc;
  my $sql = qq(
    SELECT external_db_id FROM external_db WHERE db_name = ?
  );
  my $sth = $dbc->prepare($sql);
  $sth->execute($name);
  my ($dbid) = $sth->fetchrow_array;
  foreach my $s (@{$slice->get_all_synonyms()}) {
    return $s->name if $s->external_db_id == $dbid;
  }
  return undef;
}

sub insdc_accession {
  my $self = shift;

  my $csv = $self->Obj->slice->coord_system->version; 
  my $csa = Bio::EnsEMBL::Registry->get_adaptor($self->species,'core',
                                                'CoordSystem');
  # 0 = look on chromosome
  # 1 = look on supercontig/scaffold
  # maybe in future 2 = ... ?
  for(my $method = 0;$method < 2;$method++) {
    my $slice;
    if($method == 0) {
      $slice = $self->Obj->slice->sub_Slice($self->Obj->start,
                                            $self->Obj->end);
    } elsif($method == 1) {
      # Try to project to supercontig (aka scaffold)
      foreach my $level (qw(supercontig scaffold)) {
        next unless $csa->fetch_by_name($level,$csv);
        my $gsa = $self->Obj->project($level,$csv);
        if(@$gsa==1) {
          $slice = $gsa->[0]->to_Slice;
          last;
        }
      }
    }
    if($slice) {
      my $name = $self->_insdc_synonym($slice,'INSDC');
      if($name) {
        return join(':',$slice->coord_system->name,$csv,$name,
                      $slice->start,$slice->end,$slice->strand);
      }
    }
  }
  return undef;
}

sub count_xrefs {
  my $self = shift;
  my $type = $self->get_db;
  my $dbc = $self->database($type)->dbc;

  # xrefs on the gene
  my $xrefs_c = 0;
  my $sql = '
    SELECT x.display_label, edb.db_name, edb.status
      FROM gene g, object_xref ox, xref x, external_db edb
     WHERE g.gene_id = ox.ensembl_id
       AND ox.xref_id = x.xref_id
       AND x.external_db_id = edb.external_db_id
       AND ox.ensembl_object_type = "Gene"
       AND g.gene_id = ?';

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
    next if ($db_name =~ /ENSG|OTTG/);
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
      #before we can tell if they match the CDS / UTR
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
        if ((abs($trans->coding_region_start-$evi->seq_region_start) < 4)
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

    foreach my $isf (@{$trans->get_all_IntronSupportingEvidence}) {
      push @{$e->{$tsi}{'intron_supporting_evidence'}},$isf->hit_name;
    }


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

# generate URLs for evidence links
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

sub get_Slice {
  my ($self, $context, $ori) = @_;
  
  my $slice = $self->Obj->feature_Slice;
  $context  = $slice->length * $1 / 100 if $context =~ /(\d+)%/;
  $slice    = $slice->invert if $ori && $slice->strand != $ori;
  
  return $slice->expand($context, $context);
}

sub short_caption {
  my $self = shift;
  
  return 'Gene-based displays' unless shift eq 'global';
  
  my $dxr   = $self->Obj->can('display_xref') ? $self->Obj->display_xref : undef;
  my $label = $dxr ? $dxr->display_id : $self->Obj->stable_id;
  
  return "Gene: $label";  
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

sub gene                        { return $_[0]->Obj;             }
sub type_name                   { return $_[0]->species_defs->translate('Gene'); }
sub stable_id                   { return $_[0]->Obj->stable_id;  }
sub feature_type                { return $_[0]->Obj->type;       }
sub source                      { return $_[0]->Obj->source;     }
sub version                     { return $_[0]->Obj->version;    }
sub logic_name                  { return $_[0]->Obj->analysis->logic_name; }
sub coord_system                { return $_[0]->Obj->slice->coord_system->name; }
sub seq_region_type             { return $_[0]->coord_system;    }
sub seq_region_name             { return $_[0]->Obj->slice->seq_region_name; }
sub seq_region_start            { return $_[0]->Obj->start;      }
sub seq_region_end              { return $_[0]->Obj->end;        }
sub seq_region_strand           { return $_[0]->Obj->strand;     }
sub feature_length              { return $_[0]->Obj->feature_Slice->length; }
sub get_latest_incarnation      { return $_[0]->Obj->get_latest_incarnation; }
sub get_all_associated_archived { return $_[0]->Obj->get_all_associated_archived; }
sub gxa_check                   { return; } #implemented in widget plugin, to check for gene expression atlas availability


sub get_database_matches {
  my $self = shift;
  my $dbpat = shift;
  my @DBLINKS;
  eval { @DBLINKS = @{$self->Obj->get_all_DBLinks($dbpat)};};
  return \@DBLINKS  || [];
}

sub get_all_transcripts {
  my $self = shift;
  unless ($self->{'data'}{'_transcripts'}){
    foreach my $transcript (@{$self->gene()->get_all_Transcripts}){
      my $transcriptObj = $self->new_object(
        'Transcript', $transcript, $self->__data
      );
      $transcriptObj->gene($self->gene);
      push @{$self->{'data'}{'_transcripts'}} , $transcriptObj;
    }
  }
  return $self->{'data'}{'_transcripts'};
}

sub get_all_families {
  my $self = shift;
  my $compara_db = shift || 'compara';

  my $families;
  if (ref($self->gene) =~ /Family/) { ## No gene in URL, so CoreObjects fetches a family instead
    ## Explicitly set db connection, as registry is buggy!
    my $family = $self->gene;
    my $dba = $self->database('core', $self->species);
    my $genome_db = $self->database($compara_db)->get_GenomeDBAdaptor->fetch_by_name_assembly($self->species);
    my $members = $family->get_Member_by_source_GenomeDB('ENSEMBLPEP', $genome_db);
    my $info = {'description' => $family->description};
    my $genes = [];
    my $prots = {};
    foreach my $member (@$members) {
      my $gene = $member->gene_member->get_Gene;
      push @$genes, $gene;
      my $protein = $member->get_Translation;
      if ($prots->{$gene->stable_id}) {
        push @{$prots->{$gene->stable_id}}, $protein;
      }
      else {
        $prots->{$gene->stable_id} = [$protein];
      }
    }
    $info->{'genes'}    = $genes;
    $info->{'proteins'} = $prots;
    $info->{'count'}    = @$genes;
    $families->{$self->param('family')} = {'info' => $info};
  }
  else {
    foreach my $transcript (@{$self->get_all_transcripts}) {
      my $trans_families = $transcript->get_families($compara_db);
      while (my ($id, $info) = each (%$trans_families)) {
        if (exists $families->{$id}) {
          push @{$families->{$id}{'transcripts'}}, $transcript;
        }
        else {
          $families->{$id} = {'info' => $info, 'transcripts' => [$transcript]};
        }
      }
    }
  }
  return $families;
}

sub create_family {
  my ($self, $id, $cmpdb) = @_; 
  $cmpdb ||= 'compara';
  my $databases = $self->database($cmpdb) ;
  my $family_adaptor;
  eval{ $family_adaptor = $databases->get_FamilyAdaptor };
  if ($@){ warn($@); return {} }
  return $family_adaptor->fetch_by_stable_id($id);
}

sub display_xref {
  my $self = shift; 
  return undef if $self->Obj->isa('Bio::EnsEMBL::Compara::Family');
  return undef if $self->Obj->isa('Bio::EnsEMBL::ArchiveStableId');
  my $trans_xref = $self->Obj->display_xref();
  return undef unless  $trans_xref;
  (my $db_display_name = $trans_xref->db_display_name) =~ s/(.*HGNC).*/$1 Symbol/; #hack for HGNC name labelling, remove in e58
  return ($trans_xref->display_id, $trans_xref->dbname, $trans_xref->primary_id, $db_display_name, $trans_xref->info_text );
}

sub mod_date {
  my $self = shift;
  my $time = $self->gene()->modified_date;
  return $self->date_format( $time,'%d/%m/%y' );
}

sub created_date {
  my $self = shift;
  my $time = $self->gene()->created_date;
  return $self->date_format( $time,'%d/%m/%y' );
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

sub retrieve_remarks {
  my $self = shift;
  my @remarks = grep {$_ ne 'EnsEMBL merge exception'} map { $_->value } @{ $self->Obj->get_all_Attributes('remark') };
  return \@remarks;
}

sub gene_type {
  my $self = shift;
  my $db = $self->get_db;
  my $type = '';
  if( $db eq 'core' ){
    $type = ucfirst(lc($self->Obj->status))." ".$self->Obj->biotype;
    $type =~ s/_/ /;
    $type ||= $self->db_type;
  } elsif ($db =~ /vega/) {
    my $biotype = ($self->Obj->biotype eq 'tec') ? uc($self->Obj->biotype) : ucfirst(lc($self->Obj->biotype));
    $type = ucfirst(lc($self->Obj->status))." $biotype";
    $type =~ s/_/ /g;
    $type =~ s/unknown //i;
    return $type;
  } else {
    $type = $self->logic_name;
    if ($type =~/^(proj|assembly_patch)/ ){
      $type = ucfirst(lc($self->Obj->status))." ".$self->Obj->biotype;
    }
    $type =~ s/_/ /g;
    $type =~ s/^ccds/CCDS/;
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

sub get_alternative_locations {
  my $self = shift;
  my @alt_locs = map { [ $_->slice->seq_region_name, $_->start, $_->end, $_->slice->coord_system->name ] }
     @{$self->Obj->get_all_alt_locations};
  return \@alt_locs;
}

sub get_desc_mapping {
### Returns descriptions for ortholog types.
### TODO - get this info from compara API
  my ($self, $match_type) = @_;
  my %desc_mapping;

  my %orth_mapping = (
      ortholog_one2one          => '1 to 1 orthologue',
      apparent_ortholog_one2one => '1 to 1 orthologue (apparent)',
      ortholog_one2many         => '1 to many orthologue',
      ortholog_many2many        => 'many to many orthologue',
      possible_ortholog         => 'possible orthologue',
  );
  my %para_mapping = (
      within_species_paralog    => 'paralogue (within species)',
      other_paralog             => 'other paralogue (within species)',
      putative_gene_split       => 'putative gene split',
      contiguous_gene_split     => 'contiguous gene split',
  );

  if ($match_type eq 'Orthologue') {
    %desc_mapping = %orth_mapping;
  }
  elsif ($match_type eq 'Paralogue') {
    %desc_mapping = %para_mapping;
  }
  else {
    %desc_mapping = (%orth_mapping, %para_mapping);
  }
  return %desc_mapping;
}

sub get_homology_matches {
  my ($self, $homology_source, $homology_description, $disallowed_homology, $compara_db) = @_;
  #warn ">>> MATCHING $homology_source, $homology_description BUT NOT $disallowed_homology";
  
  $homology_source      ||= 'ENSEMBL_HOMOLOGUES';
  $homology_description ||= 'ortholog';
  $compara_db           ||= 'compara';
  
  my $key = "$homology_source::$homology_description";
  
  if (!$self->{'homology_matches'}{$key}) {
    my $homologues = $self->fetch_homology_species_hash($homology_source, $homology_description, $compara_db);
    
    return $self->{'homology_matches'}{$key} = {} unless keys %$homologues;
    
    my $gene         = $self->Obj;
    my $geneid       = $gene->stable_id;
    my $adaptor_call = $self->param('gene_adaptor') || 'get_GeneAdaptor';
    my %homology_list;

    # Convert descriptions into more readable form
    my %desc_mapping = $self->get_desc_mapping;
    
    foreach my $display_spp (keys %$homologues) {
      my $order = 0;
      
      foreach my $homology (@{$homologues->{$display_spp}}) { 
        my ($homologue, $homology_desc, $species_tree_node, $query_perc_id, $target_perc_id, $dnds_ratio, $gene_tree_node_id, $homology_id) = @$homology;
        
        next unless $homology_desc =~ /$homology_description/;
        next if $disallowed_homology && $homology_desc =~ /$disallowed_homology/;
        
        # Avoid displaying duplicated (within-species and other paralogs) entries in the homology table (e!59). Skip the other_paralog (or overwrite it)
        next if $homology_list{$display_spp}{$homologue->stable_id} && $homology_desc eq 'other_paralog';
        
        $homology_list{$display_spp}{$homologue->stable_id} = { 
          homologue           => $homologue,
          homology_desc       => $Bio::EnsEMBL::Compara::Homology::PLAIN_TEXT_WEB_DESCRIPTIONS{$homology_desc} || 'no description',
          description         => $homologue->description       || 'No description',
          display_id          => $homologue->display_label     || 'Novel Ensembl prediction',
          species_tree_node   => $species_tree_node,
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

sub get_homologies {
  my $self                 = shift;
  my $homology_source      = shift;
  my $homology_description = shift;
  my $compara_db           = shift || 'compara';
  
  $homology_source      = 'ENSEMBL_HOMOLOGUES' unless defined $homology_source;
  $homology_description = 'ortholog' unless defined $homology_description;
  
  my $geneid   = $self->stable_id;
  my $database = $self->database($compara_db);
  my %homologues;

  return unless $database;
  
  $self->timer_push('starting to fetch', 6);

  my $query_member   = $database->get_GeneMemberAdaptor->fetch_by_stable_id($geneid);

  return unless defined $query_member;
  
  my $homology_adaptor = $database->get_HomologyAdaptor;
  my $homologies_array = $homology_adaptor->fetch_all_by_Member($query_member); # It is faster to get all the Homologues and discard undesired entries than to do fetch_all_by_Member_method_link_type
  #warn ">>> @$homologies_array";

  $self->timer_push('fetched', 6);

  # Strategy: get the root node (this method gets the whole lineage without getting sister nodes)
  # We use right - left indexes to get the order in the hierarchy.
  
  my %classification = ( Undetermined => 99999999 );
  
  if (my $taxon = $query_member->taxon) {
    my $node = $taxon->root;

    while ($node) {
      $node->get_tagvalue('scientific name');
      
      # Found a speed boost with nytprof -- avilella
      # $classification{$node->get_tagvalue('scientific name')} = $node->right_index - $node->left_index;
      $classification{$node->{_tags}{'scientific name'}} = $node->{'_right_index'} - $node->{'_left_index'};
      $node = $node->children->[0];
    }
  }
  
  $self->timer_push('classification', 6);
  
  my $ok_homologies = [];
  foreach my $homology (@$homologies_array) {
    push @$ok_homologies, $homology if $homology->description =~ /$homology_description/;
  }
  return ($ok_homologies, \%classification, $query_member);
}
    
sub fetch_homology_species_hash {
  my $self                 = shift;
  my $homology_source      = shift;
  my $homology_description = shift;
  my $compara_db           = shift || 'compara';
  my ($homologies, $classification, $query_member) = $self->get_homologies($homology_source, $homology_description, $compara_db);
  my %homologues;

  foreach my $homology (@$homologies) {
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
    push @{$homologues{ucfirst $genome_db_name}}, [ $target_member, $homology->description, $homology->species_tree_node(), $query_perc_id, $target_perc_id, $dnds_ratio, $homology->{_gene_tree_node_id}, $homology->dbID ];
  }
  
  $self->timer_push('homologies hacked', 6);
  
  @{$homologues{$_}} = sort { $classification->{$a->[2]} <=> $classification->{$b->[2]} } @{$homologues{$_}} for keys %homologues;
  
  return \%homologues;
}

sub get_homologue_alignments {
  my $self        = shift;
  my $compara_db  = shift || 'compara';
  my $database    = $self->database($compara_db);
  my $hub         = $self->hub;
  my $msa;

  if ($database) {  
    my $member  = $database->get_GeneMemberAdaptor->fetch_by_stable_id($self->Obj->stable_id);
    my $tree    = $database->get_GeneTreeAdaptor->fetch_default_for_Member($member);
    my @params  = ($member, 'ENSEMBL_ORTHOLOGUES');
    my $species = [];
    foreach (grep { /species_/ } $hub->param) {
      (my $sp = $_) =~ s/species_//;
      push @$species, $sp if $hub->param($_) eq 'yes';
    }
    push @params, $species if scalar @$species;
    $msa        = $tree->get_alignment_of_homologues(@params);
    $tree->release_tree;
  }
  return $msa;
}

sub get_compara_Member {
  my $self       = shift;
  my $compara_db = shift || 'compara';
  my $cache_key  = "_compara_member_$compara_db";
  
  if (!$self->{$cache_key}) {
    my $compara_dba = $self->database($compara_db)              || return;
    my $adaptor     = $compara_dba->get_adaptor('GeneMember')   || return;
    my $member      = $adaptor->fetch_by_stable_id($self->stable_id);
    
    $self->{$cache_key} = $member if $member;
  }
  
  return $self->{$cache_key};
}

sub get_GeneTree {
  my $self       = shift;
  my $compara_db = shift || 'compara';
  my $whole_tree = shift;
  my $clusterset_id = $self->hub->param('clusterset_id') || 'default';
  my $cache_key  = sprintf('_protein_tree_%s_%s', $compara_db, $clusterset_id);

  if (!$self->{$cache_key}) {
    my $member  = $self->get_compara_Member($compara_db)           || return;
    my $adaptor = $member->adaptor->db->get_adaptor('GeneTree')    || return;
    my $tree    = $adaptor->fetch_all_by_Member($member, -clusterset_id => $clusterset_id)->[0];
    unless ($tree) {
        $tree = $adaptor->fetch_default_for_Member($member);
    }
    return unless $tree;
    return $tree if $whole_tree;
    
    $tree->preload;
    $self->{$cache_key} = $tree->root;
    $self->{"_member_$compara_db"} = $member;

    my $parent      = $adaptor->fetch_parent_tree($tree);
    if ($parent->tree_type ne 'clusterset') {
      my %subtrees;
      my $total_leaves = 0;
      foreach my $subtree (@{$adaptor->fetch_subtrees($parent)}) {
        $subtrees{$subtree->{_parent_id}} = ($tree->root_id eq $subtree->root_id ? $tree : $subtree);
      }
      $parent->preload;
      foreach my $leaf (@{$parent->root->get_all_leaves}) {
        my $subtree = $subtrees{$leaf->node_id};
        $leaf->{'_subtree'} = $subtree;
        $leaf->{'_subtree_size'} = $subtree->get_tagvalue('gene_count');
        $total_leaves += $leaf->{'_subtree_size'};
      }
      $parent->{'_total_num_leaves'} = $total_leaves;
      $tree->{'_supertree'} = $parent;
    }
  }
  return $self->{$cache_key};
}

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

# Function to call compara API to get the species Tree
sub get_SpeciesTree {
  my $self       = shift;  
  my $compara_db = shift || 'compara';

  my $hub            = $self->hub;  
  my $collapsability = $hub->param('collapsability');
  my $cache_key      = "_species_tree_".$collapsability."_".$compara_db;
  my $database       = $self->database($compara_db);

  if (!$self->{$cache_key}) {
    my $cafeTree_Adaptor = $database->get_CAFEGeneFamilyAdaptor();
    my $geneTree_Adaptor = $database->get_GeneTreeAdaptor();
    
    my $member   = $self->get_compara_Member($compara_db)           || return;        
    my $geneTree = $geneTree_Adaptor->fetch_default_for_Member($member) || return;
    my $cafeTree = $cafeTree_Adaptor->fetch_by_GeneTree($geneTree) || return;		   
    
    $cafeTree->multifurcate_tree();
    $cafeTree    = $cafeTree->root($cafeTree->root->lca_reroot($cafeTree->lca_id)) if($collapsability eq 'part');     
      
    $self->{$cache_key} = $cafeTree;
  }
  
  return $self->{$cache_key};
}

# Calls for GeneSNPView

# Valid user selections
sub valids {
  my $self = shift;
  my %valids = (); # Now we have to create the snp filter
  
  foreach ($self->param) {
    $valids{$_} = 1 if $_ =~ /opt_/ && $self->param($_) eq 'on';
  }
  
  return \%valids;
}

sub getVariationsOnSlice {
  my( $self, $slice, $subslices, $gene, $so_terms ) = @_;
  my $sliceObj = $self->new_object('Slice', $slice, $self->__data);
  
  my ($count_snps, $filtered_snps, $context_count) = $sliceObj->getFakeMungedVariationFeatures($subslices,$gene,$so_terms);
  $self->__data->{'sample'}{"snp_counts"} = [$count_snps, scalar @$filtered_snps];
  $self->__data->{'SNPS'} = $filtered_snps; 
  return ($count_snps, $filtered_snps, $context_count);
}

sub store_TransformedTranscripts {
  my( $self ) = @_;
  my $focus_transcript = $self->hub->type eq 'Transcript' ? $self->param('t') : undef;
 
  my $offset = $self->__data->{'slices'}{'transcripts'}->[1]->start -1;
  foreach my $trans_obj ( @{$self->get_all_transcripts} ) {
    next if $focus_transcript && $trans_obj->stable_id ne $focus_transcript;
    my $transcript = $trans_obj->Obj;
    my ($raw_coding_start,$coding_start);
    if (defined( $transcript->coding_region_start )) {    
      $raw_coding_start = $transcript->coding_region_start;
      $raw_coding_start -= $offset;
      $coding_start = $raw_coding_start + $self->munge_gaps( 'transcripts', $raw_coding_start );
    }
    else {
      $coding_start  = undef;
      }

    my ($raw_coding_end,$coding_end);
    if (defined( $transcript->coding_region_end )) {
      $raw_coding_end = $transcript->coding_region_end;
      $raw_coding_end -= $offset;
      $coding_end = $raw_coding_end   + $self->munge_gaps( 'transcripts', $raw_coding_end );
    }
    else {
      $coding_end = undef;
    }
    my $raw_start = $transcript->start;
    my $raw_end   = $transcript->end  ;
    my @exons = ();
    foreach my $exon (@{$transcript->get_all_Exons()}) {
      my $es = $exon->start - $offset; 
      my $ee = $exon->end   - $offset;
      my $O = $self->munge_gaps( 'transcripts', $es );
      push @exons, [ $es + $O, $ee + $O, $exon ];
    }
    $trans_obj->__data->{'transformed'}{'exons'}        = \@exons;
    $trans_obj->__data->{'transformed'}{'coding_start'} = $coding_start;
    $trans_obj->__data->{'transformed'}{'coding_end'}   = $coding_end;
    $trans_obj->__data->{'transformed'}{'start'}        = $raw_start;
    $trans_obj->__data->{'transformed'}{'end'}          = $raw_end;
  }
}

sub get_included_so_terms {
  my $self     = shift;

  # map the selected consequence type to SO terms
  my %cons = %Bio::EnsEMBL::Variation::Utils::Constants::OVERLAP_CONSEQUENCES;
  my %options =  EnsEMBL::Web::Constants::VARIATION_OPTIONS; 

  my $hub  = $self->hub;

  my %selected_so;

  foreach ($hub->param) {
    if ($hub->param($_) eq 'on' && $_ =~ /opt_/ && exists($options{'type'}{$_})) {
      foreach my $con (keys %cons) {
        my $consequence = "opt_" . lc $cons{$con}->SO_term;
        $selected_so{$con} = 1 if $_ eq $consequence;
      }
    }
  }

  my @so_terms = keys %selected_so;
  return \@so_terms;
}

sub store_TransformedSNPS {
  my $self     = shift;
  my $so_terms = shift;
  my $vfs      = shift;

  my $valids   = $self->valids;
  
  my $tva = $self->get_adaptor('get_TranscriptVariationAdaptor', 'variation');
  
  my @transcripts = @{$self->get_all_transcripts};
  if ($self->hub->type eq 'Transcript'){
    @transcripts = ($self->hub->core_object('transcript'));
  }

  my $included_so;
  if ($self->need_consequence_check) {
    $included_so = $self->get_included_so_terms;
  }

  # get all TVs and arrange them by transcript stable ID and VF ID, ignore non-valids
  my $tvs_by_tr;
  
  my $method        = 'fetch_all_by_VariationFeatures';
  my $have_so_terms = (defined $so_terms && scalar @$so_terms);
  my $filtered_vfs  = $vfs;

  if ($have_so_terms) {
    # tva needs an ontology term adaptor to fetch by SO term
    $tva->{_ontology_adaptor} ||= $self->hub->get_databases('go')->{'go'}->get_OntologyTermAdaptor;
  
    $method .= '_SO_terms';

    my %term_hash;
    foreach my $so_term (@$so_terms) {
      $term_hash{$so_term} = 1;
    }

    my @vfs_with_term = grep { scalar map { $term_hash{$_} ? 1 : () } @{$_->consequence_type('SO')} } @$vfs;
    $filtered_vfs = \@vfs_with_term;
  }

  my $tvs;
  if (!$have_so_terms && $included_so ) {
    $tva->{_ontology_adaptor} ||= $self->hub->get_databases('go')->{'go'}->get_OntologyTermAdaptor;
    $tvs = $tva->fetch_all_by_VariationFeatures_SO_terms($filtered_vfs,[map {$_->transcript} @transcripts],$included_so,1) ;
  } else {
    $tvs = $tva->$method($filtered_vfs,[map {$_->transcript} @transcripts],$so_terms,0, $included_so) ;
  }

  if (!$self->need_consequence_check) {
    foreach my $tv (@$tvs) {
      $tvs_by_tr->{$tv->transcript->stable_id}->{$tv->variation_feature->dbID} = $tv;
    }
  } else {
    foreach my $tv (@$tvs) {
      my $found = 0;
      foreach my $type(@{$tv->consequence_type || []}) {
        if (exists($valids->{'opt_'.lc($type)})) {
          $tvs_by_tr->{$tv->transcript->stable_id}->{$tv->variation_feature->dbID} = $tv;
          $found=1;
          last;
        }
      }
    }
  }
  
  # then store them in the transcript's data hash
  my $total_tv_count = 0;
  foreach my $trans_obj (@{$self->get_all_transcripts}) {
    $trans_obj->__data->{'transformed'}{'snps'} = $tvs_by_tr->{$trans_obj->stable_id};    
    $total_tv_count += scalar(keys %{$tvs_by_tr->{$trans_obj->stable_id}});
  }
}

sub store_ConsequenceCounts {
  my $self     = shift;
  my $so_term_sets = shift;
  my $vfs      = shift;

  my $tva = $self->get_adaptor('get_TranscriptVariationAdaptor', 'variation');
  
  my @transcripts = @{$self->get_all_transcripts};
  if ($self->hub->type eq 'Transcript'){
    @transcripts = ($self->hub->core_object('transcript'));
  }

  my $included_so;

  if ($self->need_consequence_check) {
    # Can't use counts with consequence check so clear any existing stored conscounts and return - no longer true
    # if (exists($self->__data->{'conscounts'})) { delete $self->__data->{'conscounts'}; }
    #return;
    $included_so = $self->get_included_so_terms;
  }

  $tva->{_ontology_adaptor} ||= $self->hub->get_databases('go')->{'go'}->get_OntologyTermAdaptor;

  my %conscounts;

  foreach my $cons (keys %$so_term_sets) {
    my $filtered_vfs = $vfs;

    my $so_terms = $so_term_sets->{$cons};

    my %term_hash = map {$_ => 1} @$so_terms;
  
    my @vfs_with_term = grep { scalar map { $term_hash{$_} ? 1 : () } @{$_->consequence_type()} } @$vfs;
    $filtered_vfs = \@vfs_with_term;
  
    $conscounts{$cons} = $tva->count_all_by_VariationFeatures_SO_terms($filtered_vfs,[map {$_->transcript} @transcripts],$so_terms,$included_so) ;;
  }
  
  if (!$included_so) {
    $conscounts{'ALL'} = $tva->count_all_by_VariationFeatures($vfs,[map {$_->transcript} @transcripts]) ;
  } else {
    $conscounts{'ALL'} = $tva->count_all_by_VariationFeatures_SO_terms($vfs,[map {$_->transcript} @transcripts], $included_so) ;
  }
  
  # then store them in the gene's data hash
  $self->__data->{'conscounts'} = \%conscounts;
}

sub need_consequence_check {
  my( $self ) = @_; 

  my %options =  EnsEMBL::Web::Constants::VARIATION_OPTIONS; 

  my $hub  = $self->hub;

  foreach ($hub->param) {
    if ($hub->param($_) eq 'off' && $_ =~ /opt_/ && exists($options{'type'}{$_})) {
      return 1;
    }
  }

  return 0;
}

sub store_TransformedDomains {
  my( $self, $key ) = @_; 
  my %domains;
  my $focus_transcript = $self->hub->type eq 'Transcript' ? $self->param('t') : undef;

  my $offset = $self->__data->{'slices'}{'transcripts'}->[1]->start -1;
  foreach my $trans_obj ( @{$self->get_all_transcripts} ) {
    next if $focus_transcript && $trans_obj->stable_id ne $focus_transcript;
    my %seen;
    my $transcript = $trans_obj->Obj; 
    next unless $transcript->translation; 
    foreach my $pf ( @{$transcript->translation->get_all_ProteinFeatures( lc($key) )} ) { 
## rach entry is an arry containing the actual pfam hit, and mapped start and end co-ordinates
      if (exists $seen{$pf->display_id}{$pf->start}){
        next;
      } else {
        $seen{$pf->display_id}->{$pf->start} =1;
        my @A = ($pf);  
        foreach( $transcript->pep2genomic( $pf->start, $pf->end ) ) {
          my $O = $self->munge_gaps( 'transcripts', $_->start - $offset, $_->end - $offset) - $offset; 
          push @A, $_->start + $O, $_->end + $O;
        } 
        push @{$trans_obj->__data->{'transformed'}{lc($key).'_hits'}}, \@A;
      }
    }
  }
}

sub munge_gaps {
  my( $self, $slice_code, $bp, $bp2  ) = @_;
  my $subslices = $self->__data->{'slices'}{ $slice_code }[2];
  foreach( @$subslices ) {

    if( $bp >= $_->[0] && $bp <= $_->[1] ) {
      return defined($bp2) && ($bp2 < $_->[0] || $bp2 > $_->[1] ) ? undef : $_->[2] ;
    }
  }
  return undef;
}

sub get_munged_slice {
  my $self          = shift;
  my $master_config = undef;
  if (ref($_[0]) =~ /ImageConfig/) {
    $master_config = shift;
  } else {
    shift;
  } 

  my $slice         = $self->get_Slice(@_);
  my $stable_id     = $self->stable_id;
  my $length        = $slice->length; 
  my $munged        = '0' x $length;
  my $context       = $self->param('context') || 100;
  my $extent        = $context eq 'FULL' ? 5000 : $context;
  my $features      = $slice->get_all_Genes(undef, $self->param('opt_db'));
  my @lengths;
  my $offset;

  # Allow return of data for a single transcript
  my $page_type     = $self->hub->type;
  my $focus_transcript = $page_type eq 'Transcript' ? $self->param('t') : undef;  
  
  if ($context eq 'FULL') {
    @lengths = ($length);
  } else {
    foreach my $gene (grep { $_->stable_id eq $stable_id } @$features) {   
      foreach my $transcript (@{$gene->get_all_Transcripts}) {
        next if $focus_transcript && $transcript->stable_id ne $focus_transcript; 
        if (defined($offset)) {
          if ($offset > $transcript->start-$extent) {
            $offset = $transcript->start-$extent;
          }
        } else {
          $offset = $transcript->start-$extent;
        }
        foreach my $exon (@{$transcript->get_all_Exons}) { 
          my $start       = $exon->start - $extent;
          my $exon_length = $exon->end   - $exon->start + 1 + 2 * $extent;
          if ($start-1 >= 0) {
            substr($munged, $start - 1, $exon_length) = '1' x $exon_length;
          } else {
            warn "Got negative substr when munging slices - don't think this should happen\n";
            substr($munged, 0, $exon_length - $start) = '1' x $exon_length;
          }
        }
      }
    }
    
    $munged =~ s/^0+//;
    $munged =~ s/0+$//;
    @lengths = map length($_), split /(0+)/, $munged;
  }

  # @lengths contains the sizes of gaps and exons(+/- context)

  $munged = undef;

  my $collapsed_length = 0;
  my $flag             = 0;
  my $subslices        = [];
  my $pos              = $offset; 
  
  foreach (@lengths, 0) {
    if ($flag = 1 - $flag) {
      push @$subslices, [ $pos + 1, 0, 0 ];
      $collapsed_length += $_;
    } else {
      $subslices->[-1][1] = $pos;
    }
    
    $pos += $_;
  }
  # compute the width of the slice image within the display
  my $pixel_width =
    ($master_config ? $master_config->get_parameter('image_width') : 800) - 
    ($master_config ? $master_config->get_parameter('label_width') : 100) -
    ($master_config ? $master_config->get_parameter('margin')      :   5) * 3;

  # Work out the best size for the gaps between the "exons"
  my $fake_intron_gap_size = 11;
  my $intron_gaps          = $#lengths / 2;
  
  if ($intron_gaps * $fake_intron_gap_size > $pixel_width * 0.75) {
    $fake_intron_gap_size = int($pixel_width * 0.75 / $intron_gaps);
  }
  
  # Compute how big this is in base-pairs
  my $exon_pixels    = $pixel_width - $intron_gaps * $fake_intron_gap_size;
  my $scale_factor   = $collapsed_length / $exon_pixels;
  my $padding        = int($scale_factor * $fake_intron_gap_size) + 1;
  $collapsed_length += $padding * $intron_gaps;

  # Compute offset for each subslice
  my $start = 0;
  foreach (@$subslices) {
    $_->[2] = $start  - $_->[0];
    $start += $_->[1] - $_->[0] - 1 + $padding;
  }
  
  return [ 'munged', $slice, $subslices, $collapsed_length ];
}

# Calls for HistoryView

sub get_archive_object {
  my $self = shift;
  my $id = $self->stable_id;
  my $archive_adaptor = $self->database('core')->get_ArchiveStableIdAdaptor;
  my $archive_object = $archive_adaptor->fetch_by_stable_id($id, 'Gene');
  return $archive_object;
}

=head2 history

 Arg1        : data object
 Description : gets the deduplicated archive id history tree based around this ID
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

=head2 get_predecessors

 Arg1        : data object
 Description : gets the complete archive id history tree based around this ID
 Return type : listref of Bio::EnsEMBL::ArchiveStableId

=cut

sub get_predecessors {
  my $self = shift;
  my $archive_adaptor = $self->database('core')->get_ArchiveStableIdAdaptor;
  my $archive = $archive_adaptor->fetch_by_stable_id($self->stable_id, 'Gene');
  return [] unless $archive;
  my $predecessors = $archive_adaptor->fetch_predecessor_history($archive);
  return $predecessors;
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

sub get_feature_view_link {
  my ($self, $feature) = @_;
  my $feature_id  = $feature->display_label;
  my $feature_set = $feature->feature_set->name;
  
  return if $feature_set =~ /cisRED|CRM/i;
  
  my $link = $self->hub->url({
    type   => 'Location',
    action => 'Genome',
    ftype  => 'RegulatoryFactor',
    fset   =>  $feature_set,
    id     =>  $feature_id,
  });

  return qq{<span class="small"><a href="$link">[view all]</a></span>};
}

sub get_extended_reg_region_slice {
  my $self = shift;
  ## retrieve default slice
  my $object_slice = $self->Obj->feature_Slice;
     $object_slice = $object_slice->invert if $object_slice->strand < 1; ## Put back onto correct strand!


  my $fg_db = $self->get_fg_db;
  my $fg_slice_adaptor = $fg_db->get_SliceAdaptor;
  my $fsets = $self->feature_sets;
  my $gr_slice = $fg_slice_adaptor->fetch_by_Gene_FeatureSets($self->Obj, $fsets);
  $gr_slice = $gr_slice->invert if $gr_slice->strand < 1; ## Put back onto correct strand!


  ## Now we need to extend the slice!! Default is to add 2kb to either end of slice, if gene_reg slice is
  ## extends more than this use the values returned from this
  my $start = $self->Obj->start;
  my $end   = $self->Obj->end;

  my $gr_start = $gr_slice->start;
  my $gr_end = $gr_slice->end;
  my ($new_start, $new_end);

  if ( ($start  - 2000) < $gr_start) {
     $new_start = 2000;
  } else {
     $new_start = $start - $gr_start;
  }

  if ( ($end +2000) > $gr_end) {
    $new_end = 2000;
  }else {
    $new_end = $gr_end - $end;
  }

  my $extended_slice =  $object_slice->expand($new_start, $new_end);
  return $extended_slice;
}

sub feature_sets {
  my $self = shift;

  my $available_sets = $self->species_defs->databases->{'DATABASE_FUNCGEN'}->{'FEATURE_SETS'};
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
  my $fg_slice_adaptor = $fg_db->get_SliceAdaptor;
  my $slice = $self->get_extended_reg_region_slice;
  my $factors_by_gene = $ext_feat_adaptor->fetch_all_by_Gene_FeatureSets($gene, $fsets, 1);
  my $factors_by_slice = $ext_feat_adaptor->fetch_all_by_Slice_FeatureSets($slice, $fsets);

  my (%seen, @factors_to_return);

  foreach (@$factors_by_gene){
   my $label = $_->display_label .':'.  $_->start .''.$_->end;
   unless (exists $seen{$label}){
      push @factors_to_return, $_;
      $seen{$label} = 1;
   }
  }

  foreach (@$factors_by_slice){
   my $label = $_->display_label .':'. $_->start .''.$_->end;
   unless (exists $seen{$_->display_label}){
      push @factors_to_return, $_;
      $seen{$label} = 1;
   }
  }

 return \@factors_to_return;
}

sub reg_features {
  my $self = shift; 
  my $gene = $self->gene;
  my $fg_db= $self->get_fg_db; 
  my $slice =  $self->get_extended_reg_region_slice;
  my $reg_feat_adaptor = $fg_db->get_RegulatoryFeatureAdaptor; 
  my $feats = $reg_feat_adaptor->fetch_all_by_Slice($slice);
  return $feats;

}

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

sub get_similarity_hash {
  my ($self, $recurse, $obj) = @_;
  $obj ||= $self->Obj;
  my $DBLINKS;
  eval { $DBLINKS = $obj->get_all_DBEntries; };
  warn ("SIMILARITY_MATCHES Error on retrieving gene DB links $@") if ($@);
  return $DBLINKS  || [];
}

sub get_rnaseq_tracks {
  my $self = shift;
  my $tracks = [];
  my $rnaseq_db = $self->hub->database('rnaseq');
  if ($rnaseq_db) {
    my $aa = $self->hub->get_adaptor('get_AnalysisAdaptor', 'rnaseq');
    $tracks = [ grep { $_->displayable } @{$aa->fetch_all} ];
  }
  return $tracks;
}

sub can_export {
  my $self = shift;
  
  return $self->action =~ /^(Export|Sequence|TranscriptComparison|Compara_Alignments|Compara_Tree|SpeciesTree|Compara_Ortholog|Compara_Paralog|Family)$/ ? 0 : $self->availability->{'gene'};
}

1;
