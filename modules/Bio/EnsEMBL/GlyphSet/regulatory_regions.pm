package Bio::EnsEMBL::GlyphSet::regulatory_regions;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub squish { return 1; }

sub get_feature_sets {
  my ($self, $fg_db) = @_;
  my @fsets;
  my $feature_set_adaptor = $fg_db->get_FeatureSetAdaptor;

  my @sources;
  my $spp = $ENV{'ENSEMBL_SPECIES'}; warn $spp;
  if ($spp eq 'Homo_sapiens'){
   @sources = ('miRanda miRNA', 'cisRED motifs', 'VISTA enhancer set');
  } elsif ($spp eq 'Mus_musculus'){
   @sources = ('cisRED motifs');
  }
  elsif ($spp eq 'Drosophila_melanogaster'){
   @sources = ('BioTIFFIN motifs', 'REDfly CRMs', 'REDfly TFBSs');
  }

  foreach my $name ( @sources){
    push @fsets, $feature_set_adaptor->fetch_by_name($name);
  }
  
  return \@fsets;
}

sub features {
  my ($self) = @_;
  my $slice = $self->{'container'};
  my $wuc = $self->{'config'};
  my @fsets;
 
  my $efg_db = undef;
  my $db_type  = $self->my_config('db_type')||'funcgen';
  unless($slice->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice")) {
    $efg_db = $slice->adaptor->db->get_db_adaptor($db_type);
    if(!$efg_db) {
      warn("Cannot connect to $db_type db");
      return [];
    }
  }

  if ($wuc->cache('feature_sets') ){ @fsets = @{$wuc->cache('feature_sets')}; }
  else { @fsets = @{$self->get_feature_sets($efg_db)}; }

 
  ## Remove CisRED search region feature set (drawn by another glyphset)
  my @sets; 
  foreach my $set (@fsets){
   unless ($set->name =~/cisRED\s+search\s+regions/){ push (@sets, $set);}
  } 
     
  my $external_Feature_adaptor  = $efg_db->get_ExternalFeatureAdaptor;
  my $f = $external_Feature_adaptor->fetch_all_by_Slice_FeatureSets($slice, \@sets);
  ## If for gene regulation view display only those features that are linked to the gene 
  if ($wuc->cache('gene')) {
    my @gene_assoc_feats;
    my $gene = $wuc->cache('gene');
    foreach my $feat (@$f){ 
      my $db_ent = $feat->get_all_DBEntries;
      foreach my $dbe (@{$db_ent}){
        if ( $gene->stable_id eq $dbe->primary_id ) {
          push (@gene_assoc_feats, $feat);
        }
      }         
    } 
   $f = \@gene_assoc_feats;
  }

  my $count = 0;
  foreach my $feat (@$f){
   $wuc->cache($feat->display_label, $count);   
   $count ++;
   if ($count >= 15) {$count = 0;} 
  } 
  return $f;
}

sub href {
  my ($self, $f) = @_;
  return $self->_url($self->zmenu($f));
}

sub zmenu {
    my ($self, $f ) = @_;
    my $db_ent = $f->get_all_DBEntries; 
    my $name = $f->display_label;
      
    my $type = $f->feature_type->name;     
    my $analysis = $f->analysis->logic_name;   
    my $feature_link;
  
    my $species = $self->{'config'}->{'species'};
    my $seq_region = $f->slice->seq_region_name;
    my ($start,$end) = $self->slice2sr( $f->start, $f->end );
    my ($factor, $feature);

    my $return = {
        caption                    => 'regulatory_regions',
        "100:Location:"            => $seq_region.":".$start."-".$end,
        "80:Analysis:"             => $analysis 
    };
    if ($analysis =~/cisRED/){
      $name =~/\D+(\d+)/;
       my $i = $name;
       $i=~s/\D*//;
       if ($species =~/Homo_sapiens/){
        $feature_link = "http://www.cisred.org/human9/siteseq?fid=$i";
       } elsif ($species =~/Mus_musculus/) {
        $feature_link = "http://www.cisred.org/mouse4/siteseq?fid=$i"; 
       }        
       $factor = $name;
       my $feat_name = $name;
       $name .= "  [CisRed]";
     #  $return->{"01:Feature: $name"} = $feature_link;
       $factor=~s/\D*//; 
       
    } elsif ($analysis =~/miRanda/){
       $name =~/\D+(\d+)/;
       my $temp_factor = $name;
       my @temp = split (/\:/, $temp_factor);
       $factor = $temp[1];    
       
      # $return->{"01:Feature: $name"} = "";
    } elsif ($analysis =~/VISTA/){
       $name =~/\D+(\d+)/;
       my $temp_factor = $name;
       my @temp = split (/\:/, $temp_factor);
       $factor = $temp[1];

       #$return->{"01:Feature: $name"} = "";
    }elsif ($analysis =~/MICA/){
       $name =~/\D+(\d+)/;
       $factor = $name;
       my $feature_link = "http://servlet.sanger.ac.uk/tiffin/motif.jsp?acc=$name";
       #$return->{"01:Feature: $name"} = $feature_link;
    }else {
       if ($analysis!~/\w+/){
        $factor = "Unknown";  
        #$return->{"01:Feature: $name"} = "";
       } else {
        $factor = $name; 
        #$return->{"01:Feature: $name"} = "";
      }
    }

    $return->{"90:Feature:"} = $name;
    if ($factor) { $return->{"70:Factor:"} = $factor;}

    my ($assoc, $type);
    foreach my $dbe (@{$db_ent}){
       $assoc = $dbe->primary_id;
       my $dbname = $dbe->dbname;
       if ($dbname =~/gene/i) {$type = "gene";}
       elsif ($dbname =~/transcript/i){$type = "transcript";}
       elsif ($dbname =~/translation/i){$type = "peptide"; }
    }

    $return->{"80:Associated $type:"} = $assoc;
   
    return $return;
}

sub colour_key {
  my ($self, $f) = @_;
  my $wuc = $self->{'config'}; 
  my $colour = $wuc->cache($f->display_label); 
  return $colour;
}


# Features associated with the same factor should be in the same colour
# Choose a colour from the pool
#sub colour_key {
#  my ($self, $f) = @_;
#  my $name = $f->display_label; warn $name;


#}

=pod
sub colour {
  my ($self, $f) = @_;
  my $name = $f->display_label; warn $name;
#  my $name = $f->factor->name;
  unless ( exists $self->{'config'}{'pool'} ) {
    $self->{'config'}{'pool'} = $self->{'config'}->colourmap->{'colour_sets'}{'synteny'};
    $self->{'config'}{'ptr'}  = 0;
  }
  $self->{'config'}{'_factor_colours'}||={};
  my $return = $self->{'config'}{'_factor_colours'}{ "$name" };

  unless( $return ) {
    $return = $self->{'config'}{'_factor_colours'}{"$name"} = $self->{'config'}{'pool'}[ ($self->{'config'}{'ptr'}++)  %@{$self->{'config'}{'pool'}} ];
  } 
  return $return, $return;
}

=cut
1;
