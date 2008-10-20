package EnsEMBL::Web::Object::Gene;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Proxy::Object;
use EnsEMBL::Web::Proxy::Factory;
use EnsEMBL::Web::Cache;

use Time::HiRes qw(time);

use base qw(EnsEMBL::Web::Object);

our $MEMD = new EnsEMBL::Web::Cache;

sub availability {
  my $self = shift;
  my $hash = $self->_availability;
  if( $self->Obj->isa('Bio::EnsEMBL::ArchiveStableId') ) {
    $hash->{'history'}    = 1;
  } elsif( $self->Obj->isa('Bio::EnsEMBL::Gene') ) {
    $hash->{'history'}    = 1;
    $hash->{'gene'}       = 1;
  } elsif( $self->Obj->isa('Bio::EnsEMBL::Compara::Family' ) ) {
warn "FAMILY............";
    $hash->{'family'}     = 1;
  }
  return $hash;
}

sub analysis {
  my $self = shift;
  return $self->Obj->analysis;
}
sub counts {
  my $self = shift;
  my $obj = $self->Obj;

  return {} unless $obj->isa('Bio::EnsEMBL::Gene');
  my $key = '::COUNTS::GENE::'.
            $ENV{ENSEMBL_SPECIES}                 .'::'.
            $self->core_objects->{parameters}{db} .'::'.
            $self->core_objects->{parameters}{g}  .'::';

  my $counts;

  $counts = $MEMD->get($key) if $MEMD;
  
  unless ($counts) {
    $counts = {};
    $counts->{'transcripts'} = @{$obj->get_all_Transcripts};
    $counts->{'exons'}       = @{$obj->get_all_Exons};
    $counts->{'similarity_matches'} = $self->count_xrefs;
    my $compara_db = $self->database('compara');
    if($compara_db) {
      my $compara_dbh = $compara_db->get_MemberAdaptor->dbc->db_handle;
      if($compara_dbh) {
        my %res = map { @$_ } @{$compara_dbh->selectall_arrayref('
              select ml.type, count(*) as N
                from member as m, homology_member as hm, homology as h,
                     method_link as ml, method_link_species_set as mlss
               where m.stable_id = ? and hm.member_id = m.member_id and
                     h.homology_id = hm.homology_id and 
                     mlss.method_link_species_set_id = h.method_link_species_set_id and
                     ml.method_link_id = mlss.method_link_id and
                     ( ml.type = "ENSEMBL_ORTHOLOGUES" or
                       ml.type = "ENSEMBL_PARALOGUES" and
                       h.description = "within_species_paralog" )
               group by type', {}, $obj->stable_id
        )};
        #warn keys %res;
        $counts->{'orthologs'} = $res{'ENSEMBL_ORTHOLOGUES'};
        $counts->{'paralogs'} = $res{'ENSEMBL_PARALOGUES'};
        my ($res) = $compara_dbh->selectrow_array(
          'select count(*) from family_member fm, member as m where fm.member_id=m.member_id and stable_id=?',
          {}, $obj->stable_id
        );
        $counts->{'families'}    = $res;
      }
    }

    $MEMD->set($key, $counts, undef, 'COUNTS') if $MEMD;
  }
  
  return $counts;
}

sub count_xrefs {
    my $self = shift;
    my $type = $self->get_db;
    my $dbc = $self->database($type)->dbc;

    #xrefs on the gene
    my $xrefs_c = 0;
    my $sql = qq(
                SELECT distinct(x.display_label)
                  FROM object_xref ox, xref x, external_db edb
                 WHERE ox.xref_id = x.xref_id
                   AND x.external_db_id = edb.external_db_id
                   AND ox.ensembl_object_type = 'Gene'
                   AND ox.ensembl_id = ?);
    my $sth = $dbc->prepare($sql);
    $sth->execute($self->Obj->dbID);
    while (my ($label) = $sth->fetchrow_array) {
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
    my $self = shift;
    my $obj = $self->Obj;
    my $species = $self->species;
    my $dbentry_adap = Bio::EnsEMBL::Registry->get_adaptor($species, "core", "DBEntry");
    my $o_type = $self->get_db;
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
           if ($o_type eq 'vega') {
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
       if ($o_type ne 'vega') {
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
       my $display = $self->get_ExtURL_link( $hit_name, $db_name, $hit_name );
       push @{$links}, [$display,$hit_name];
    }
    return $links;
}

sub get_slice_object {
  my $self = shift;
  my $slice = $self->Obj->feature_Slice->expand( $self->param('flank5_display'), $self->param('flank3_display') );
  return 1 unless $slice;
  my $T = new EnsEMBL::Web::Proxy::Object( 'Slice', $slice, $self->__data );
  #  $T->highlight_display( $self->Obj->get_all_Exons );
  return $T;
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

sub gene_name {
  my $self = shift;
  my( $disp_id ) = $self->display_xref;
  return $disp_id || $self->stable_id;
}

sub short_caption {
  my $self = shift;
  return $self->type_name.': '.$self->gene_name;
}

sub caption           {
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

sub type_name         { my $self = shift; return $self->species_defs->translate('Gene'); }
sub gene              { my $self = shift; return $self->Obj;             }
sub stable_id         { my $self = shift; return $self->Obj->stable_id;  }
sub feature_type      { my $self = shift; return $self->Obj->type;       }
sub source            { my $self = shift; return $self->Obj->source;     }
sub version           { my $self = shift; return $self->Obj->version;    }
sub logic_name        { my $self = shift; return $self->Obj->analysis->logic_name; }
sub coord_system      { my $self = shift; return $self->Obj->slice->coord_system->name; }
sub seq_region_type   { my $self = shift; return $self->coord_system;    }
sub seq_region_name   { my $self = shift; return $self->Obj->slice->seq_region_name; }
sub seq_region_start  { my $self = shift; return $self->Obj->start;      }
sub seq_region_end    { my $self = shift; return $self->Obj->end;        }
sub seq_region_strand { my $self = shift; return $self->Obj->strand;     }
sub feature_length    { my $self = shift; return $self->Obj->feature_Slice->length; }

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

sub get_all_transcripts{
  my $self = shift;
  unless ($self->{'data'}{'_transcripts'}){
    foreach my $transcript (@{$self->gene()->get_all_Transcripts}){
      my $transcriptObj = EnsEMBL::Web::Proxy::Object->new(
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
  my $families;
  foreach my $transcript (@{$self->get_all_transcripts}) {
    my $trans_families = $transcript->get_families;
    while (my ($id, $info) = each (%$trans_families)) {
      if (exists $families->{$id}) {
        push @{$families->{$id}{'transcripts'}}, $transcript;
      }
      else {
        $families->{$id} = {'info' => $info, 'transcripts' => [$transcript]};
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

sub member_by_source {
  my ($self, $family, $source) = @_;
  return $family->get_Member_Attribute_by_source($source) || [];
}

sub chromosome {
  my $self = shift;
  return undef if lc($self->coord_system) ne 'chromosome';
  return $self->Obj->slice->seq_region_name;
}

sub display_xref {
  my $self = shift; 
  return undef if $self->Obj->isa('Bio::EnsEMBL::Compara::Family');
  return undef if $self->Obj->isa('Bio::EnsEMBL::ArchiveStableId');
  my $trans_xref = $self->Obj->display_xref();
  return undef unless  $trans_xref;
  return ($trans_xref->display_id, $trans_xref->dbname, $trans_xref->primary_id, $trans_xref->db_display_name, $trans_xref->info_text );
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

sub get_db {
  my $self = shift;
  my $db = $self->param('db') || 'core';
  return $db eq 'est' ? 'otherfeatures' : $db;
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
    $type = $self->logic_name;
    $type ||= $self->db_type;
  } elsif ($db eq 'vega') {
    my $biotype = ($self->Obj->biotype eq 'tec') ? uc($self->Obj->biotype) : ucfirst(lc($self->Obj->biotype));
    $type = ucfirst(lc($self->Obj->status))." $biotype";
    $type =~ s/_/ /g;
    $type =~ s/unknown //i;
    return $type;
  } else {
    $type = $self->db_type;
    $type ||= $self->logic_name;
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

sub get_homology_matches{
  my( $self,$homology_source,$homology_description ) = @_;
  $homology_source      = "ENSEMBL_HOMOLOGUES" unless defined $homology_source;
  $homology_description = "ortholog"           unless defined $homology_description;

  unless( $self->{'homology_matches'}{$homology_source.'::'.$homology_description} ) { 
    my %homologues = %{$self->fetch_homology_species_hash($homology_source, $homology_description)};
    unless( keys %homologues ) {
      $self->{'homology_matches'}{$homology_source.'::'.$homology_description} = {};
      return {};
    }
    my $gene          = $self->Obj;
    my $geneid        = $gene->stable_id;
    my %homology_list;
    my $adaptor_call  = $self->param('gene_adaptor') || 'get_GeneAdaptor';

  # hash to convert descriptions into more readable form

    my %desc_mapping = (
      'ortholog_one2one'          => '1-to-1',
      'apparent_ortholog_one2one' => '1-to-1 (apparent)', 
      'ortholog_one2many'         => '1-to-many',
      'between_species_paralog'   => 'paralogue (between species)',
      'ortholog_many2many'        => 'many-to-many',
      'within_species_paralog'    => 'paralog (within species)'
    );

    foreach my $displayspp (keys (%homologues)){
      ( my $spp = $displayspp ) =~ tr/ /_/;
      my $order=0;
      foreach my $homology (@{$homologues{$displayspp}}){ 
        my ($homologue, $homology_desc, $homology_subtype, $query_perc_id, $target_perc_id, $dnds_ratio) = @{$homology};
  
        next unless ($homology_desc =~ /$homology_description/);
        my $homologue_id  = $homologue->stable_id;        
        $homology_desc = $desc_mapping{$homology_desc};   # mapping to more readable form
        $homology_desc = "no description" unless (defined $homology_desc);
        $homology_list{$displayspp}{$homologue_id}{'homology_desc'}       = $homology_desc ;
        $homology_list{$displayspp}{$homologue_id}{'homology_subtype'}    = $homology_subtype ;
        $homology_list{$displayspp}{$homologue_id}{'spp'}                 = $displayspp ;
        $homology_list{$displayspp}{$homologue_id}{'sp_common'}           = $homologue->taxon ? $homologue->taxon->common_name : '';
        $homology_list{$displayspp}{$homologue_id}{'description'}         = $homologue->description || 'No description';
        $homology_list{$displayspp}{$homologue_id}{'order'}               = $order ;
        $homology_list{$displayspp}{$homologue_id}{'query_perc_id'}       = $query_perc_id ;
        $homology_list{$displayspp}{$homologue_id}{'target_perc_id'}      = $target_perc_id ;
        $homology_list{$displayspp}{$homologue_id}{'homology_dnds_ratio'} = $dnds_ratio; 
        $homology_list{$displayspp}{$homologue_id}{'display_id'}          = $homologue->display_label || 'Novel Ensembl prediction';
        $order++;
      }
    }
    $self->{'homology_matches'}{$homology_source.'::'.$homology_description} = \%homology_list;
  }
  return $self->{'homology_matches'}{$homology_source.'::'.$homology_description};
}


sub fetch_homology_species_hash {
  my $self = shift;
  my $homology_source = shift;
  my $homology_description = shift;
  
  
  $homology_source = "ENSEMBL_HOMOLOGUES" unless (defined $homology_source);
  $homology_description= "ortholog" unless (defined $homology_description);
  
  my $geneid = $self->stable_id;
  my $database = $self->database('compara') ;
  my %homologues;

  return {} unless $database;
  $self->timer_push( 'starting to fetch' , 6 );

  my $member_adaptor = $database->get_MemberAdaptor;
  my $query_member = $member_adaptor->fetch_by_source_stable_id("ENSEMBLGENE",$geneid);

  return {} unless defined $query_member ;
  my $homology_adaptor = $database->get_HomologyAdaptor;
#  It is faster to get all the Homologues and discard undesired entries
#  my $homologies_array = $homology_adaptor->fetch_all_by_Member_method_link_type($query_member,$homology_source);
  my $homologies_array = $homology_adaptor->fetch_all_by_Member($query_member);

  $self->timer_push( 'fetched' , 6 );

  # Strategy: get the root node (this method gets the whole lineage without getting sister nodes)
  # We use right - left indexes to get the order in the hierarchy.
  my $node = $query_member->taxon->root();
  my %classification;
  while ($node){
    $node->get_tagvalue('scientific name');
    $classification{$node->get_tagvalue('scientific name')} = $node->right_index - $node->left_index;
    $node = $node->children->[0];
  }
 
  $self->timer_push( 'classification' , 6 );
 
 foreach my $homology (@{$homologies_array}){
    next unless ($homology->description =~ /$homology_description/);
    my ($query_perc_id, $target_perc_id, $genome_db_name, $target_member, $dnds_ratio);
    foreach my $member_attribute (@{$homology->get_all_Member_Attribute}) {
      my ($member, $attribute) = @{$member_attribute};
      if ($member->stable_id eq $query_member->stable_id) {
        $query_perc_id  = $attribute->perc_id;
      } else {
        $target_perc_id = $attribute->perc_id;
        $genome_db_name = $member->genome_db->name;
        $target_member  = $member;
        $dnds_ratio     = $homology->dnds_ratio; 
      }
    }  
    push (@{$homologues{$genome_db_name}}, [ $target_member, $homology->description, $homology->subtype, $query_perc_id, $target_perc_id, $dnds_ratio ]);
  }

  $self->timer_push( 'homologies hacked', 6 );
  foreach my $species_name (keys %homologues){
    @{$homologues{$species_name}} = sort {$classification{$a->[2]} <=> $classification{$b->[2]}} @{$homologues{$species_name}};

  }
  
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

  # Catch coderef
  my $error = sub{ warn($_[0]); $self->{_compara_member}=0; return 0};

  unless( defined( $self->{_compara_member} ) ){ # Look in cache
    # Prepare the adaptors
    my $compara_dba = $self->database( 'compara' )           || &$error( "No compara db" );
    my $member_adaptor = $compara_dba->get_adaptor('Member') || &$error( "Cannot COMPARA->get_adaptor('Member')" );
    # Fetch the object
    my $id = $self->stable_id;
    my $member = $member_adaptor->fetch_by_source_stable_id('ENSEMBLGENE',$id) || &$error( "<h3>No compara ENSEMBLGENE member for $id</h3>" );
    # Update the cache
    $self->{_compara_member} = $member;
  }
  # Return cached value
  return $self->{_compara_member};
}

sub get_ProteinTree{
  # Returns the Bio::EnsEMBL::Compara::ProteinTree object
  # corresponding to this gene
  my $self = shift;

  # Where to keep the cached data
  my $cachekey = '_protein_tree';

  # Catch coderef
  my $error = sub{ warn($_[0]); $self->{$cachekey}=0; return 0};

  unless( defined( $self->{$cachekey} ) ){ # Look in cache
    # Fetch the objects
    my $member = $self->get_compara_Member
        || &$error( "No compara member for this gene" );
    my $tree_adaptor = $member->adaptor->db->get_adaptor('ProteinTree')
        || &$error( "Cannot COMPARA->get_adaptor('ProteinTree')" );
    my $tree = $tree_adaptor->fetch_by_Member_root_id($member, 0) 
        || &$error( "No compara tree for ENSEMBLGENE $member" );
    # Update the cache
    $self->{$cachekey} = $tree;
  }
  # Return cached value
  return $self->{$cachekey};
}

#----------------------------------------------------------------------

sub get_das_factories {
   my $self = shift;
   return [ $self->__data->{_object}->adaptor()->db()->_each_DASFeatureFactory ];
}

sub get_das_features_by_name {
  my $self = shift;
  my $name  = shift || die( "Need a source name" );
  my $scope = shift || '';
  my $data = $self->__data;     
  my $cache = $self->Obj;
  $cache->{_das_features} ||= {}; # Cache
  my %das_features;
  foreach my $dasfact( @{$self->get_das_factories} ){
    my $type = $dasfact->adaptor->type;
    next if $dasfact->adaptor->type =~ /^ensembl_location/;
    my $name = $dasfact->adaptor->name;
    next unless $name;
    my $dsn = $dasfact->adaptor->dsn;
    my $url = $dasfact->adaptor->url;

# Construct a cache key : SOURCE_URL/TYPE
# Need the type to handle sources that serve multiple types of features

    my $key = $url || $dasfact->adaptor->protocol .'://'.$dasfact->adaptor->domain;
    if ($key =~ m!/das$!) {
  $key .= "/$dsn";
    }
    $key .= "/$type";
    unless( $cache->{_das_features}->{$key} ) { ## No cached values - so grab and store them!!
      my $featref = ($dasfact->fetch_all_by_ID($data->{_object}, $data ))[1];
      $cache->{_das_features}->{$key} = $featref;
    }
    $das_features{$name} = $cache->{_das_features}->{$key};
  }
  return @{ $das_features{$name} || [] };
}

sub get_das_features_by_slice {
  my $self = shift;
  my $name  = shift || die( "Need a source name" );
  my $slice = shift || die( "Need a slice" );
  
  my $cache = $self->Obj;     

  $cache->{_das_features} ||= {}; # Cache
  my %das_features;
    
  foreach my $dasfact( @{$self->get_das_factories} ){
    my $type = $dasfact->adaptor->type;
    next unless $dasfact->adaptor->type =~ /^ensembl_location/;
    my $name = $dasfact->adaptor->name;
    next unless $name;
    my $dsn = $dasfact->adaptor->dsn;
    my $url = $dasfact->adaptor->url;

# Construct a cache key : SOURCE_URL/TYPE
# Need the type to handle sources that serve multiple types of features

    my $key = $url || $dasfact->adaptor->protocol .'://'.$dasfact->adaptor->domain;
    $key .= "/$dsn/$type";

    unless( $cache->{_das_features}->{$key} ) { ## No cached values - so grab and store them!!
      my $featref = ($dasfact->fetch_all_Features( $slice, $type ))[0];
      $cache->{_das_features}->{$key} = $featref;
    }
    $das_features{$name} = $cache->{_das_features}->{$key};
  }

  return @{ $das_features{$name} || [] };
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
  my %valids = ();    ## Now we have to create the snp filter....
  foreach( $self->param() ) {
    $valids{$_} = 1 if $_=~/opt_/ && $self->param( $_ ) eq 'on';
  }
  return \%valids;
}

sub getVariationsOnSlice {
  my( $self, $slice, $subslices, $gene ) = @_;
  my $sliceObj = EnsEMBL::Web::Proxy::Object->new(
        'Slice', $slice, $self->__data
       );
  
  my ($count_snps, $filtered_snps, $context_count) = $sliceObj->getFakeMungedVariationFeatures($subslices,$gene);  
  $self->__data->{'sample'}{"snp_counts"} = [$count_snps, scalar @$filtered_snps];
  $self->__data->{'SNPS'} = $filtered_snps; 
  return ($count_snps, $filtered_snps, $context_count);
}


sub get_source {
  my $self = shift;
  my $default = shift;

  my $vari_adaptor = $self->Obj->adaptor->db->get_db_adaptor('variation');
  unless ($vari_adaptor) {
    warn "ERROR: Can't get variation adaptor";
    return ();
  }

  if ($default) {
    return  $vari_adaptor->get_VariationAdaptor->get_default_source();
  }
  else {
    return $vari_adaptor->get_VariationAdaptor->get_all_sources();
  }

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
  my $self = shift;
  my $valids = $self->valids;
  foreach my $trans_obj ( @{$self->get_all_transcripts} ) {
    my $T = $trans_obj->stable_id;
    my $snps = {};
    foreach my $S ( @{$self->__data->{'SNPS'}} ) {
      foreach( @{$S->[2]->get_all_TranscriptVariations||[]} ) {
  next unless  $T eq $_->transcript->stable_id;
  foreach my $type ( @{ $_->consequence_type || []} ) {
    next unless $valids->{'opt_'.lc($type)};
    $snps->{ $S->[2]->dbID } = $_;
    last;
  }
      }
    }
    $trans_obj->__data->{'transformed'}{'snps'} = $snps;
  }
}

sub store_TransformedDomains {
  my( $self, $key ) = @_; 
  my %domains;
  my $offset = $self->__data->{'slices'}{'transcripts'}->[1]->start -1;
  foreach my $trans_obj ( @{$self->get_all_transcripts} ) {
    my $transcript = $trans_obj->Obj;
    next unless $transcript->translation; 
    foreach my $pf ( @{$transcript->translation->get_all_ProteinFeatures($key)} ) { 
## rach entry is an arry containing the actual pfam hit, and mapped start and end co-ordinates
      my @A = ($pf);
      foreach( $transcript->pep2genomic( $pf->start, $pf->end ) ) {
        my $O = $self->munge_gaps( 'transcripts', $_->start - $offset, $_->end - $offset) - $offset; 
        push @A, $_->start + $O, $_->end + $O;
      } 
      push @{$trans_obj->__data->{'transformed'}{lc($key).'_hits'}}, \@A;
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

sub generate_query_hash {
  my $self = shift;
  return {
    'gene' => $self->stable_id,
    'db'   => $self->get_db,
  };

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
  my $fg_db = $self->get_fg_db;
  my @fsets; 
  my $feature_set_adaptor = $fg_db->get_FeatureSetAdaptor;

  my @sources;
  my $spp = $ENV{'ENSEMBL_SPECIES'};
  if ($spp eq 'Homo_sapiens'){
   @sources = ('RegulatoryFeatures', 'miRanda miRNA', 'cisRED search regions', 'cisRED motifs', 'VISTA enhancer set'); 
  } elsif ($spp eq 'Mus_musculus'){
   @sources = ('cisRED search regions', 'cisRED motifs');
  } 
  elsif ($spp eq 'Drosophila_melanogaster'){ 
   @sources = ('BioTIFFIN motifs', 'REDfly CRMs', 'REDfly TFBSs'); 
  }

  foreach my $name ( @sources){
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
  my $fsets = $self->feature_sets; 
  my $fg_db= $self->get_fg_db; 
  my $slice = $self->get_Slice( @_ );

  my $reg_feat_adaptor = $fg_db->get_RegulatoryFeatureAdaptor; 
  my $feats = $reg_feat_adaptor->fetch_all_by_Slice($slice);
  return $feats;

}

sub features {
  my $self = shift;
  my $gene_id = $self->stable_id; 

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
  
  my $feature_set_adaptor = $fg_db->get_FeatureSetAdaptor;
  my $external_Feature_adaptor = $fg_db->get_ExternalFeatureAdaptor;
  my $f;
  my $species = $ENV{'ENSEMBL_SPECIES'}; 
     if ($species =~/Homo_sapiens/){
         my $cisred_fset = $feature_set_adaptor->fetch_by_name('cisRED group motifs');
         my $cis_fset = $feature_set_adaptor->fetch_by_name('cisRED search regions');
         my $miranda_fset = $feature_set_adaptor->fetch_by_name('miRanda miRNA');
         my $vista_fset = $feature_set_adaptor->fetch_by_name('VISTA enhancer set');
         $f = $external_Feature_adaptor->fetch_all_by_Slice_FeatureSets($slice, [$cisred_fset, $cis_fset, $miranda_fset, $vista_fset]);
      } elsif ($species=~/Mus_musculus/){
         my $cisred_fset = $feature_set_adaptor->fetch_by_name('cisRED group motifs');
         $f = $external_Feature_adaptor->fetch_all_by_Slice_FeatureSets($slice, [$cisred_fset]);
     } elsif ($species=~/Drosophila/){
         my $tiffin_fset = $feature_set_adaptor->fetch_by_name('BioTIFFIN motifs');
         my $crm_fset = $feature_set_adaptor->fetch_by_name('REDfly CRMs');
         my $tfbs_fset = $feature_set_adaptor->fetch_by_name('REDfly TFBSs');
         $f = $external_Feature_adaptor->fetch_all_by_Slice_FeatureSets($slice, [$tiffin_fset, $crm_fset, $tfbs_fset]);
     }

  my @features;
  my $offset =  $slice->start -1 ;
  my %seen_feat;
   
  foreach my $feat (@$f){
    my $db_ent = $feat->get_all_DBEntries;
    my $feat_id = $feat->display_label;
     foreach my $dbe (@{$db_ent}){
       if ($dbe->primary_id eq $gene_id ) {  
        push (@features, $feat); 
        }
     }
  }
  my $feats = \@features;
  return $feats || [];

}


=head2 vega_projection

 Arg[1]       : EnsEMBL::Web::Proxy::Object
 Arg[2]       : Alternative assembly name
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

sub get_similarity_hash{
  my $self = shift;
  my $DBLINKS;
  eval { $DBLINKS = $self->Obj->get_all_DBEntries; };
  warn ("SIMILARITY_MATCHES Error on retrieving gene DB links $@") if ($@);
  return $DBLINKS  || [];
}


1;

__END__


sub features
  Input:       EnsEMBL::Web::Gene object
  Description:  Returns all the features that regulate this gene
  Output:      Array ref

