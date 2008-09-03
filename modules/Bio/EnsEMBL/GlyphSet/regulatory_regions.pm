package Bio::EnsEMBL::GlyphSet::regulatory_regions;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub squish { return 1; }

sub features {
  my ($self) = @_;
  my $slice = $self->{'container'};
  my $efg_db = undef;
  my $db_type  = $self->my_config('db_type')||'funcgen';
  unless($slice->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice")) {
    $efg_db = $slice->adaptor->db->get_db_adaptor($db_type);
    if(!$efg_db) {
      warn("Cannot connect to $db_type db");
      return [];
    }
  }
  my $feature_set_adaptor       = $efg_db->get_FeatureSetAdaptor; 
  my $species                   = $self->{'config'}->{'species'}; 
  my $external_Feature_adaptor  = $efg_db->get_ExternalFeatureAdaptor; 
   
  my $gene = $self->{'config'}->{'_draw_single_Gene'};
  if( $gene ) {
     my $gene_id = $gene->stable_id; 
     my $f; 
     if ($species =~/Homo_sapiens/){
         my $cisred_fset  = $feature_set_adaptor->fetch_by_name('cisRED group motifs');
         my $miranda_fset = $feature_set_adaptor->fetch_by_name('miRanda miRNA');
         my $vista_fset = $feature_set_adaptor->fetch_by_name('VISTA enhancer set');
         $f = $external_Feature_adaptor->fetch_all_by_Slice_FeatureSets($slice, $cisred_fset, $miranda_fset, $vista_fset);
      } elsif ($species=~/Mus_musculus/){
         my $cisred_fset = $feature_set_adaptor->fetch_by_name('cisRED group motifs');
         $f = $external_Feature_adaptor->fetch_all_by_Slice_FeatureSets($slice, $cisred_fset);
     } elsif ($species=~/Drosophila/){
         my $tiffin_fset = $feature_set_adaptor->fetch_by_name('BioTIFFIN motifs');
         my $crm_fset = $feature_set_adaptor->fetch_by_name('REDfly CRMs');
         my $tfbs_fset = $feature_set_adaptor->fetch_by_name('REDfly TFBSs');
         $f = $external_Feature_adaptor->fetch_all_by_Slice_FeatureSets($slice, $tiffin_fset, $crm_fset, $tfbs_fset);
     }
    my @features; 
    foreach my $feat (@$f){
    my $db_ent = $feat->get_all_DBEntries;
     foreach my $dbe (@{$db_ent}){ 
      if ( $gene_id eq $dbe->primary_id ) {
       #$feat->{'start'} += $offset;
       #$feat->{'end'} += $offset; 
       push (@features, $feat);
       }
     }
   }
   
    my $data = \@features;
    return $data || [];
  } else {
      my $f;
     if ($species =~/Homo_sapiens/){
         my $cisred_fset = $feature_set_adaptor->fetch_by_name('cisRED group motifs');
         my $miranda_fset = $feature_set_adaptor->fetch_by_name('miRanda miRNA');
         my $vista_fset = $feature_set_adaptor->fetch_by_name('VISTA enhancer set');
         $f = $external_Feature_adaptor->fetch_all_by_Slice_FeatureSets($slice, $cisred_fset, $miranda_fset, $vista_fset);
      } elsif ($species=~/Mus_musculus/){
         my $cisred_fset = $feature_set_adaptor->fetch_by_name('cisRED group motifs');
         $f = $external_Feature_adaptor->fetch_all_by_Slice_FeatureSets($slice, $cisred_fset);
     } elsif ($species=~/Drosophila/){
         my $tiffin_fset = $feature_set_adaptor->fetch_by_name('BioTIFFIN motifs');
         my $crm_fset = $feature_set_adaptor->fetch_by_name('REDfly CRMs');
         my $tfbs_fset = $feature_set_adaptor->fetch_by_name('REDfly TFBSs');
         $f = $external_Feature_adaptor->fetch_all_by_Slice_FeatureSets($slice, $tiffin_fset, $crm_fset, $tfbs_fset);
     }

      return $f;
  }
}

sub href {
    my ($self, $f ) = @_;
    return undef;
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

    my $return = {
        'caption'                    => 'regulatory_regions',
        "06:bp: $start-$end"         => "contigview?c=$seq_region:$start;w=1000",
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
       my $factor = $name;
       my $feat_name = $name;
       $name .= "  [CisRed]";
       $return->{"01:Feature: $name"} = $feature_link;
       $factor=~s/\D*//; 
       $return->{"02:Factor: $factor"} = "featureview?type=RegulatoryFactor;id=$factor;name=$type";
       
    } elsif ($analysis =~/miRanda/){
       $name =~/\D+(\d+)/;
       my $temp_factor = $name;
       my @temp = split (/\:/, $temp_factor);
       my $factor = $temp[1];    
       
       $return->{"01:Feature: $name"} = "";
       $return->{"02:Factor: $factor"} = "featureview?type=RegulatoryFactor;id=$factor;name=$type";
    } elsif ($analysis =~/VISTA/){
       $name =~/\D+(\d+)/;
       my $temp_factor = $name;
       my @temp = split (/\:/, $temp_factor);
       my $factor = $temp[1];

       $return->{"01:Feature: $name"} = "";
       $return->{"02:Factor: $factor"} = "featureview?type=RegulatoryFactor;id=$factor;name=$type";
    }elsif ($analysis =~/MICA/){
       $name =~/\D+(\d+)/;
       my $factor = $name;
       my $feature_link = "http://servlet.sanger.ac.uk/tiffin/motif.jsp?acc=$name";
       $return->{"01:Feature: $name"} = $feature_link;
       $return->{"02:Factor: $factor"} = "featureview?type=RegulatoryFactor;id=$factor;name=$type";
    }else {
       if ($analysis!~/\w+/){
        my $factor = "Unknown";  
        $return->{"01:Feature: $name"} = "";
        $return->{"02:Factor: $factor"} = "";
       } else {
        my $factor = $name; 
        $return->{"01:Feature: $name"} = "";
        $return->{"02:Factor: $factor"} = "featureview?type=RegulatoryFactor;id=$factor;name=$type";
      }
    }

    foreach my $dbe (@{$db_ent}){
       my $assoc = $dbe->primary_id;
       my $db_type = $dbe->dbname;
       if ($db_type =~/transcript/){$return->{"05:Associated transcript: $assoc"} = "transview?transcript=$assoc";}
       elsif ($db_type =~/gene/  ){$return->{"05:Associated gene: $assoc"} = "geneview?gene=$assoc";}
       elsif ($db_type =~/translation/){$return->{"05:Associated protein: $assoc"} = "protview?=peptide$assoc";}
     }
  
    return $return;
}



# Features associated with the same factor should be in the same colour
# Choose a colour from the pool

sub colour {
  my ($self, $f) = @_;
  my $name = $f->display_label;
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


1;
