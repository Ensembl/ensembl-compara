#$Id$
package EnsEMBL::Web::Object::Gene;

### NAME: EnsEMBL::Web::Object::Gene
### Wrapper around a Bio::EnsEMBL::Gene object  

### PLUGGABLE: Yes, using Proxy::Object 

### STATUS: At Risk
### Contains a lot of functionality not directly related to
### manipulation of the underlying API object 

### DESCRIPTION

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Cache;
use Bio::EnsEMBL::Compara::GenomeDB;

use Time::HiRes qw(time);

use base qw(EnsEMBL::Web::Object);

our $MEMD = new EnsEMBL::Web::Cache;

sub availability {
  my $self = shift;
  
  if (!$self->{'_availability'}) {
    my $availability = $self->_availability;
    my $obj = $self->Obj;
    
    if ($obj->isa('Bio::EnsEMBL::ArchiveStableId')) {
      $availability->{'history'} = 1;
    } elsif ($obj->isa('Bio::EnsEMBL::Gene')) {
      my $counts      = $self->counts;
      my $rows        = $self->table_info($self->get_db, 'stable_id_event')->{'rows'};
      my $funcgen_res = $self->database('funcgen') ? $self->table_info('funcgen', 'feature_set')->{'rows'} ? 1 : 0 : 0;
      
      my $gene_tree_sub = sub {
        my ($database_synonym) = @_;
        my $gene_tree = $self->get_GeneTree($database_synonym);
        my $has_gene_tree;
        if ($gene_tree) {
          eval { $has_gene_tree = !!$gene_tree->get_leaf_by_Member($self->get_compara_Member($database_synonym)); }
        }
        return $has_gene_tree;
      };
      
      $availability->{'history'}       = !!$rows;
      $availability->{'gene'}          = 1;
      $availability->{'core'}          = $self->get_db eq 'core';
      $availability->{'alt_allele'}    = $self->table_info($self->get_db, 'alt_allele')->{'rows'};
      $availability->{'regulation'}    = !!$funcgen_res; 
      $availability->{'family'}        = !!$counts->{families};
      $availability->{'has_gene_tree'} = $gene_tree_sub->('compara'); # FIXME: Once compara get their act together, revert to $gene_tree && $gene_tree->get_leaf_by_Member($self->{'_member_compara'});
      $availability->{"has_$_"}        = $counts->{$_} for qw(transcripts alignments paralogs orthologs similarity_matches);

      if ($self->database('compara_pan_ensembl')) {
        $availability->{'family_pan_ensembl'} = !!$counts->{families_pan};
        if($availability->{'family_pan_ensembl'}) {
          #FIXME: Suspect flag; turning it off seems to have no effect on the ability to show pan-compara families. Left in until can be verified
          $availability->{'family'} = 1; 
        }
        $availability->{'has_gene_tree_pan'}  = $gene_tree_sub->('compara_pan_ensembl');
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

sub counts {
  my $self = shift;
  my $obj = $self->Obj;

  return {} unless $obj->isa('Bio::EnsEMBL::Gene');
  
  my $key = sprintf '::COUNTS::GENE::%s::%s::%s::', $self->species, $self->hub->core_param('db'), $self->hub->core_param('g');
  my $counts = $self->{'_counts'};
  $counts ||= $MEMD->get($key) if $MEMD;
  
  if (!$counts) {
    $counts = {
      transcripts        => scalar @{$obj->get_all_Transcripts},
      exons              => scalar @{$obj->get_all_Exons},
      similarity_matches => $self->count_xrefs
    };
    
    my $compara_db = $self->database('compara');
    
    if ($compara_db) {
      my $compara_dbh = $compara_db->get_MemberAdaptor->dbc->db_handle;
      
      if ($compara_dbh) {
        $counts = {%$counts, %{$self->count_homologues($compara_dbh)}};
      
        my ($res) = $compara_dbh->selectrow_array(
          'select count(*) from family_member fm, member as m where fm.member_id=m.member_id and stable_id=?',
          {}, $obj->stable_id
        );
        
        $counts->{'families'} = $res;
      }
      
      $counts->{'alignments'} = $self->count_alignments->{'all'} if $self->get_db eq 'core';
    }

    if (my $compara_db = $self->database('compara_pan_ensembl')) {
      my $compara_dbh = $compara_db->get_MemberAdaptor->dbc->db_handle;

      my $pan_counts = {};

      if ($compara_dbh) {
        $pan_counts = $self->count_homologues($compara_dbh);
      
        my ($res) = $compara_dbh->selectrow_array(
          'select count(*) from family_member fm, member as m where fm.member_id=m.member_id and stable_id=?',
          {}, $obj->stable_id
        );
        
        $pan_counts->{'families'} = $res;
      }
      
      $pan_counts->{'alignments'} = $self->count_alignments('DATABASE_COMPARA_PAN_ENSEMBL')->{'all'} if $self->get_db eq 'core';

      foreach (keys %$pan_counts) {
	  my $key = $_."_pan";
	  $counts->{$key} = $pan_counts->{$_};
      }
    }
    
    $counts = {%$counts, %{$self->_counts}};

    $MEMD->set($key, $counts, undef, 'COUNTS') if $MEMD;
    $self->{'_counts'} = $counts;
  }
  
  return $counts;
}

sub count_homologues {
  my ($self, $compara_dbh) = @_;
  
  my $counts = {};
  
  my $res = $compara_dbh->selectall_arrayref(
    'select ml.type, h.description, count(*) as N
      from member as m, homology_member as hm, homology as h,
           method_link as ml, method_link_species_set as mlss
     where m.stable_id = ? and hm.member_id = m.member_id and
           h.homology_id = hm.homology_id and 
           mlss.method_link_species_set_id = h.method_link_species_set_id and
           ml.method_link_id = mlss.method_link_id
     group by description', {}, $self->Obj->stable_id
  );
  
  foreach (@$res) {
    if ($_->[0] eq 'ENSEMBL_PARALOGUES' && $_->[1] ne 'possible_ortholog') {
      $counts->{'paralogs'} += $_->[2];
    } elsif ($_->[1] !~ /^UBRH|BRH|MBRH|RHS$/) {
      $counts->{'orthologs'} += $_->[2];
    }
  }
  
  return $counts;
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
    my $display = $self->get_ExtURL_link( $hit_name, $db_name, $hit_name );
    push @{$links}, [$display,$hit_name];
  }
  return $links;
}

sub get_Slice {
  my( $self, $context, $ori ) = @_;
  my $db  = $self->get_db ;
  my $dba = $self->DBConnection->get_DBAdaptor($db);
  my $slice = $self->Obj->feature_Slice;
  if( $context =~ /(\d+)%/ ) {
    $context = $slice->length * $1 / 100;
  }
  if( $ori && $slice->strand != $ori ) {
    $slice = $slice->invert();
  }
  return $slice->expand( $context, $context );
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
  my( $disp_id ) = $self->display_xref;
  my $caption = $self->type_name.': ';
  if( $disp_id ) {
    $caption .= "$disp_id (".$self->stable_id.")";
  } else {
    $caption .= $self->stable_id;
  }
  return $caption;
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

sub get_database_matches {
  my $self = shift;
  my @DBLINKS;
  eval { @DBLINKS = @{$self->Obj->get_all_DBLinks};};
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
    my $genome_db = Bio::EnsEMBL::Compara::GenomeDB->new($dba);
    my $members = $family->get_all_Members;
    my $info = {'description' => $family->description};
    my $genes = [];
    foreach my $member (@$members) {
      $member->genome_db($genome_db);
      my $gene = $member->gene;
      push @$genes, $gene if $gene;
    }
    $info->{'genes'} = $genes;
    $info->{'count'} = @$genes;
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
          my @A = keys %$info;
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

sub member_by_source {
  my ($self, $family, $source) = @_;
  return $family->get_Member_Attribute_by_source($source) || [];
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
    $type = ucfirst(lc($self->Obj->status))." ".$self->Obj->biotype;
    $type =~ s/_/ /;
    $type ||= $self->db_type;
  } elsif ($db eq 'vega') {
    my $biotype = ($self->Obj->biotype eq 'tec') ? uc($self->Obj->biotype) : ucfirst(lc($self->Obj->biotype));
    $type = ucfirst(lc($self->Obj->status))." $biotype";
    $type =~ s/_/ /g;
    $type =~ s/unknown //i;
    return $type;
  } else {
    $type = $self->logic_name;
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

sub get_homology_matches {
  my ($self, $homology_source, $homology_description, $disallowed_homology, $compara_db) = @_;
  
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
    my %desc_mapping = (
      ortholog_one2one          => '1-to-1',
      apparent_ortholog_one2one => '1-to-1 (apparent)', 
      ortholog_one2many         => '1-to-many',
      possible_ortholog         => 'possible ortholog',
      ortholog_many2many        => 'many-to-many',
      within_species_paralog    => 'paralogue (within species)',
      other_paralog             => 'other paralogue (within species)',
      putative_gene_split       => 'putative gene split',
      contiguous_gene_split     => 'contiguous gene split'
    );
    
    foreach my $display_spp (keys %$homologues) {
      my $order = 0;
      
      foreach my $homology (@{$homologues->{$display_spp}}) { 
        my ($homologue, $homology_desc, $homology_subtype, $query_perc_id, $target_perc_id, $dnds_ratio, $ancestor_node_id) = @$homology;
        
        next unless $homology_desc =~ /$homology_description/;
        next if $disallowed_homology && $homology_desc =~ /$disallowed_homology/;
        
        $homology_list{$display_spp}{$homologue->stable_id} = { 
          homology_desc       => $desc_mapping{$homology_desc} || 'no description',
          description         => $homologue->description       || 'No description',
          display_id          => $homologue->display_label     || 'Novel Ensembl prediction',
          homology_subtype    => $homology_subtype,
          spp                 => $display_spp,
          query_perc_id       => $query_perc_id,
          target_perc_id      => $target_perc_id,
          homology_dnds_ratio => $dnds_ratio,
          ancestor_node_id    => $ancestor_node_id,
          order               => $order,
          location            => sprintf('%s:%s-%s:%s', map $homologue->$_, qw(chr_name chr_start chr_end chr_strand))
        };
        
        $order++;
      }
    }
    
    $self->{'homology_matches'}{$key} = \%homology_list;
  }
  
  return $self->{'homology_matches'}{$key};
}

sub fetch_homology_species_hash {
  my $self                 = shift;
  my $homology_source      = shift;
  my $homology_description = shift;
  my $compara_db           = shift || 'compara';
  
  $homology_source      = 'ENSEMBL_HOMOLOGUES' unless defined $homology_source;
  $homology_description = 'ortholog' unless defined $homology_description;
  
  my $geneid   = $self->stable_id;
  my $database = $self->database($compara_db);
  my %homologues;

  return {} unless $database;
  
  $self->timer_push('starting to fetch', 6);

  my $member_adaptor = $database->get_MemberAdaptor;
  my $query_member   = $member_adaptor->fetch_by_source_stable_id('ENSEMBLGENE', $geneid);

  return {} unless defined $query_member;
  
  my $homology_adaptor = $database->get_HomologyAdaptor;
  my $homologies_array = $homology_adaptor->fetch_all_by_Member($query_member); # It is faster to get all the Homologues and discard undesired entries than to do fetch_all_by_Member_method_link_type

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
  
  foreach my $homology (@$homologies_array) {
    next unless $homology->description =~ /$homology_description/;
    
    my ($query_perc_id, $target_perc_id, $genome_db_name, $target_member, $dnds_ratio);
    
    foreach my $member_attribute (@{$homology->get_all_Member_Attribute}) {
      my ($member, $attribute) = @$member_attribute;
      
      if ($member->stable_id eq $query_member->stable_id) {
        $query_perc_id = $attribute->perc_id;
      } else {
        $target_perc_id = $attribute->perc_id;
        $genome_db_name = $member->genome_db->name;
        $target_member  = $member;
        $dnds_ratio     = $homology->dnds_ratio; 
      }
    }
    
    # FIXME: ucfirst $genome_db_name is a hack to get species names right for the links in the orthologue/paralogue tables.
    # There should be a way of retrieving this name correctly instead.
    push @{$homologues{ucfirst $genome_db_name}}, [ $target_member, $homology->description, $homology->subtype, $query_perc_id, $target_perc_id, $dnds_ratio, $homology->ancestor_node_id];
  }
  
  $self->timer_push('homologies hacked', 6);
  
  @{$homologues{$_}} = sort { $classification{$a->[2]} <=> $classification{$b->[2]} } @{$homologues{$_}} for keys %homologues;
  
  return \%homologues;
}

sub get_compara_Member {
  # Returns the Bio::EnsEMBL::Compara::Member object
  # corresponding to this gene 
  my $self = shift;
  my $compara_db = shift || 'compara';

  # Catch coderef
  my $cachekey = "_compara_member_$compara_db";
  my $error = sub { warn($_[0]); $self->{$cachekey} = 0; return 0; };

  unless( defined( $self->{$cachekey} ) ){ # Look in cache
    # Prepare the adaptors
    my $compara_dba    = $self->database( $compara_db )      || return &$error('No compara db');
    my $member_adaptor = $compara_dba->get_adaptor('Member') || return &$error("Cannot COMPARA->get_adaptor('Member')");
    # Fetch the object
    my $id     = $self->stable_id;
    my $member = $member_adaptor->fetch_by_source_stable_id('ENSEMBLGENE', $id) || return &$error("<h3>No compara ENSEMBLGENE member for $id</h3>");
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
  my $error = sub { warn($_[0]); $self->{$cachekey} = 0; return 0; };

  unless( defined( $self->{$cachekey} ) ){ # Look in cache
    # Fetch the objects
    my $member       = $self->get_compara_Member($compara_db)               || return &$error('No compara member for this gene');
    my $proteintree_adaptor = $member->adaptor->db->get_adaptor('ProteinTree')     || return &$error("Cannot COMPARA->get_adaptor('ProteinTree')");
    my $tree;
    eval {$tree = $proteintree_adaptor->fetch_by_gene_Member_root_id($member);};
    if ($@ || !defined($tree)) {
      my $nctree_adaptor = $member->adaptor->db->get_adaptor('NCTree')     || return &$error("Cannot COMPARA->get_adaptor('NCTree')");
      $tree = $nctree_adaptor->fetch_by_gene_Member_root_id($member);
      return &$error("No compara tree for ENSEMBLGENE $member") if (!defined($tree));
    }
    # Update the cache
    $self->{$cachekey} = $tree;
    $self->{"_member_$compara_db"} = $member;
  }
  # Return cached value
  return $self->{$cachekey};
}

sub get_gene_slices {
  my( $self, $master_config, @slice_configs ) = @_;
  foreach my $array ( @slice_configs ) { 
    if($array->[1] eq 'normal') {
      my $slice= $self->get_Slice( $array->[2], 1 ); 
      $self->__data->{'slices'}{ $array->[0] } = [ 'normal', $slice, [], $slice->length ];
    } else { 
      $self->__data->{'slices'}{ $array->[0] } = $self->get_munged_slice( $master_config, $array->[2], 1 );
    }
  }
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
  my( $self, $slice, $subslices, $gene ) = @_;
  my $sliceObj = $self->new_object('Slice', $slice, $self->__data);
  
  my ($count_snps, $filtered_snps, $context_count) = $sliceObj->getFakeMungedVariationFeatures($subslices,$gene);
  $self->__data->{'sample'}{"snp_counts"} = [$count_snps, scalar @$filtered_snps];
  $self->__data->{'SNPS'} = $filtered_snps; 
  return ($count_snps, $filtered_snps, $context_count);
}

sub store_TransformedTranscripts {
  my( $self ) = @_;

  my $offset = $self->__data->{'slices'}{'transcripts'}->[1]->start -1;
  foreach my $trans_obj ( @{$self->get_all_transcripts} ) {
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

sub store_TransformedSNPS {
  my $self   = shift;
  my $valids = $self->valids;
  
  my $tva = $self->get_adaptor('get_TranscriptVariationAdaptor', 'variation');
  
  my @transcripts = @{$self->get_all_transcripts};
  
  # get all TVs and arrange them by transcript stable ID and VF ID, ignore non-valids
  my $tvs_by_tr;
  
  foreach my $tv(@{$tva->fetch_all_by_Transcripts([map {$_->transcript} @transcripts])}) {
    foreach my $type(@{$tv->consequence_type || []}) {
      next unless $valids->{'opt_'.lc($type)};
      $tvs_by_tr->{$tv->transcript->stable_id}->{$tv->{'_vf_id'}} = $tv;
      last;
    }
  }
  
  # get somatic ones too
  foreach my $tv(@{$tva->fetch_all_somatic_by_Transcripts([map {$_->transcript} @transcripts])}) {
    foreach my $type(@{$tv->consequence_type || []}) {
      next unless $valids->{'opt_'.lc($type)};
      $tvs_by_tr->{$tv->transcript->stable_id}->{$tv->{'_vf_id'}} = $tv;
      last;
    }
  }
  
  # then store them in the transcript's data hash
  $_->__data->{'transformed'}{'snps'} = $tvs_by_tr->{$_->stable_id} foreach @transcripts;
}

sub store_TransformedDomains {
  my( $self, $key ) = @_; 
  my %domains;
  my $offset = $self->__data->{'slices'}{'transcripts'}->[1]->start -1;
  foreach my $trans_obj ( @{$self->get_all_transcripts} ) {
    my %seen;
    my $transcript = $trans_obj->Obj; 
    next unless $transcript->translation; 
    foreach my $pf ( @{$transcript->translation->get_all_ProteinFeatures( lc($key) )} ) { 
## rach entry is an arry containing the actual pfam hit, and mapped start and end co-ordinates
      if (exists $seen{$pf->id}{$pf->start}){ 
        next;
      } else {
        $seen{$pf->id}->{$pf->start} =1; 
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
  my $self = shift;
  my $master_config = shift;
  my $slice = $self->get_Slice( @_ );
  my $gene_stable_id = $self->stable_id;

  my $length = $slice->length(); 
  my $munged  = '0' x $length;
  my $CONTEXT = $self->param( 'context' )|| 100;
  my $EXTENT  = $CONTEXT eq 'FULL' ? 1000 : $CONTEXT;
  ## first get all the transcripts for a given gene...
  my @ANALYSIS = ( $self->get_db() eq 'core' ? (lc($self->species_defs->AUTHORITY)||'ensembl') : 'otter' );
  @ANALYSIS = qw(ensembl havana ensembl_havana_gene) if $ENV{'ENSEMBL_SPECIES'} eq 'Homo_sapiens';
# my $features = [map { @{ $slice->get_all_Genes($_)||[]} } @ANALYSIS ];
  my $features = $slice->get_all_Genes( undef, $self->param('opt_db') );
  my @lengths;
  if( $CONTEXT eq 'FULL' ) {
    @lengths = ( $length );
  } else {
    foreach my $gene ( grep { $_->stable_id eq $gene_stable_id } @$features ) {
      foreach my $X ('1') { ## 1 <- exon+flanking, 2 <- exon only
        my $extent = $X == 1 ? $EXTENT : 0;
        foreach my $transcript (@{$gene->get_all_Transcripts()}) {
          foreach my $exon (@{$transcript->get_all_Exons()}) {
            my $START    = $exon->start            - $extent;
            my $EXON_LEN = $exon->end-$exon->start + 1 + 2 * $extent;
            substr( $munged, $START-1, $EXON_LEN ) = $X x $EXON_LEN;
          }
        }
      }
    }
    @lengths = map { length($_) } split /(0+)/, $munged;
  }
  ## @lengths contains the sizes of gaps and exons(+- context)

  $munged = undef;

  my $collapsed_length = 0;
  my $flag = 0;
  my $subslices = [];
  my $pos = 0;
  foreach(@lengths,0) {
    if ($flag=1-$flag) {
      push @$subslices, [ $pos+1, 0, 0 ] ;
      $collapsed_length += $_;
    } else {
      $subslices->[-1][1] = $pos;
    }
    $pos+=$_;
  }

## compute the width of the slice image within the display
  my $PIXEL_WIDTH =
    ($self->param('image_width')||800) -
        ( $self->param( 'label_width' ) || 100 ) -
    3 * ( $self->param( 'margin' )      ||   5 );

## Work out the best size for the gaps between the "exons"
  my $fake_intron_gap_size = 11;
  my $intron_gaps  = ((@lengths-1)/2);
  
  if( $intron_gaps * $fake_intron_gap_size > $PIXEL_WIDTH * 0.75 ) {
     $fake_intron_gap_size = int( $PIXEL_WIDTH * 0.75 / $intron_gaps );
  }
## Compute how big this is in base-pairs
  my $exon_pixels  = $PIXEL_WIDTH - $intron_gaps * $fake_intron_gap_size;
  my $scale_factor = $collapsed_length / $exon_pixels;
  my $padding      = int($scale_factor * $fake_intron_gap_size) + 1;
  $collapsed_length += $padding * $intron_gaps;

## Compute offset for each subslice
  my $start = 0;
  foreach(@$subslices) {
    $_->[2] = $start - $_->[0];
    $start += $_->[1]-$_->[0]-1 + $padding;
  }

  return [ 'munged', $slice, $subslices, $collapsed_length ];

}

# Calls for HistoryView

sub get_archive_object {
  my $self = shift;
  my $id = $self->stable_id;
  my $archive_adaptor = $self->database('core')->get_ArchiveStableIdAdaptor;
  my $archive_object = $archive_adaptor->fetch_by_stable_id($id);

 return $archive_object;
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

sub get_feature_view_link {
  my ($self, $feature) = @_;
  my $feature_id = $feature->display_label;
  my $feature_set = $feature->feature_set->name;
  return if $feature_set =~/cisRED|CRM/i;
  my $link = $self->_url({
    'type'    => 'Location',
    'action'  => 'Genome',
    'ftype'   => 'RegulatoryFactor',
    'fset'    =>  $feature_set,
    'id'      =>  $feature_id,
  });

  my $url = "<span class='small'><a href=$link>[view all]</a></span>";
  return $url;
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
  my $self = shift;
  my $DBLINKS;
  eval { $DBLINKS = $self->Obj->get_all_DBEntries; };
  warn ("SIMILARITY_MATCHES Error on retrieving gene DB links $@") if ($@);
  return $DBLINKS  || [];
}

sub viewconfig {
  my $self = shift;
  
  return $self->{'data'}->{'_viewconfig'} if $self->{'data'}->{'_viewconfig'} && !@_;
  
  my $vc = $self->get_viewconfig(@_);
  
  if ($self->action ne 'ExternalData' && !$vc->external_data) {
    $vc->external_data = 1 if $vc->add_class(sprintf 'EnsEMBL::Web::ViewConfig::%s::ExternalData', $self->type);
  }
  
  $self->{'data'}->{'_viewconfig'} ||= $vc unless @_;
  
  return $vc;
}

sub can_export {
  my $self = shift;
  
  return $self->action =~ /^Export$/ ? 0 : $self->availability->{'gene'};
}

sub default_action {
  my $self         = shift;
  my $availability = $self->availability;  
  return $availability->{'gene'} ? 'Summary' : $availability->{'idhistory'} ? 'Idhistory' : $availability->{'family'} ? 'Family' : 'Summary';
}

1;
