package Bio::EnsEMBL::GlyphSet::regulatory_search_regions;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub squish { return 1; }
sub my_label { return "cisRED search regions"; }

sub my_description { return "cisRED search regions"; }

# This for 
sub my_helplink { return "markers"; }

sub features {
    my ($self) = @_;
    my $slice = $self->{'container'};
    my $fg_db = undef;
    my $db_type  = $self->my_config('db_type')||'funcgen';
    unless($slice->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice")) {
      $fg_db = $slice->adaptor->db->get_db_adaptor($db_type);
      if(!$fg_db) {
        warn("Cannot connect to $db_type db");
        return [];
      }
    }
 
    my $feature_set_adaptor = $fg_db->get_FeatureSetAdaptor;  
    my $feature_set = $feature_set_adaptor->fetch_by_name('cisRED search regions'); 
    my $species = $self->{'config'}->{'species'}; 
    if ($species eq 'Drosophila_melanogaster' ){return;} 
   my $external_Feature_adaptor = $fg_db->get_ExternalFeatureAdaptor;
  my $gene = $self->{'config'}->{'_draw_single_Gene'};
 # warn ">>> $gene <<<";
  if( $gene ) {
    my $data =  $feature_set->get_Features_by_Slice($slice);
    return $data;
  } else 
 { 
   foreach my $search_region_feature(@{$feature_set->get_Features_by_Slice($slice)}){
    # warn "Found ".$search_region_feature->feature_type->class."\n";
   }
      return $feature_set->get_Features_by_Slice($slice);
  }
}

sub href {
  my ($self, $f) = @_;
  return $self->_url($self->zmenu($f));
}

sub zmenu {
    my ($self, $f ) = @_;
    my $name = $f->display_id;
    if (length($name) >24) { $name = "<br />$name"; }
    my $species = $self->{'config'}->{'species'};
    my $seq_region = $f->slice->seq_region_name;
    my ($start,$end) = $self->slice2sr( $f->start, $f->end );
    my $analysis = $f->analysis->logic_name;
    if ($analysis =~/cisRED/){$analysis = "cisred_search";}
    my $location = $seq_region.":".$start."-".$end;
     
   
    my $return = {
        caption   => "regulatory_search_regions",
        "100:Location:"    =>  $location,    
		 };

    my ($id, $type);
    my $db_ent = $f->get_all_DBEntries;
    foreach my $dbe (@{$db_ent}){
      $id = $dbe->primary_id;
      my $dbname = $dbe->dbname; 
      if ($dbname =~/gene/i) {$type = "gene";}
      elsif ($dbname =~/transcript/i){$type = "transcript";}
      elsif ($dbname =~/translation/i){$type = "peptide"; } 
    }
      
     if ( $type =~/^\w*/){
      my $link;
      if ($type eq 'translation') {
	$link = "protview";
	$type = "peptide";
      }
      elsif ($type eq 'transcript') {
	$link = "transview";
      }
      else {
	$link = "geneview";

      }
      if ($analysis) { my $cis_link;
      if ($species=~/Homo_sapiens/){ $cis_link = "http://www.cisred.org/human9/gene_view?ensembl_id=";}
      elsif ( $species =~/Mus_musculus/) { $cis_link = "http://www.cisred.org/mouse4/gene_view?ensembl_id=";}
     my $cisred = $analysis =~/cisred/i ? "$cis_link" . "$id" : "";
      $return->{"90:Analysis:"} = 'cisred_search';
      }
      
      $return->{"80:Associated $type:"} = $id;
    }
    return $return;
}

# Search regions with similar analyses should be in the same colour

sub colour_key {
  my ($self, $f) = @_;
  my $name = $f->feature_type->name;
  if ($name =~/cisRED\sSearch\sRegion/){return 'cisred_search'; }
  else { return};
}

sub colour {
  my ($self, $f) = @_;
  my $name = $f->analysis->logic_name;
  if ($name =~/cisRED/){$name = "cisred_search";}
  my $colour =  $self->{'config'}->colourmap->{'colour_sets'}->{'regulatory_search_regions'}{$name}[0];
  return $colour if $colour;

  unless ( exists $self->{'config'}{'pool'} ) {
    $self->{'config'}{'pool'} = $self->{'config'}->colourmap->{'colour_sets'}{'synteny'};
    $self->{'config'}{'ptr'}  = 0;
  }
  unless( $colour ) {
    $colour = $self->{'config'}{'_regulatory_search_region_colours'}{"$name"} = $self->{'config'}{'pool'}[ ($self->{'config'}{'ptr'}++)  %@{$self->{'config'}{'pool'}} ];
  }
  return $colour;
}



1;
