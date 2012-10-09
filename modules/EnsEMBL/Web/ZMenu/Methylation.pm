package EnsEMBL::Web::ZMenu::Methylation;

use strict;

use List::Util qw(max);
use List::MoreUtils qw(pairwise);

use base qw(EnsEMBL::Web::ZMenu);

use Bio::EnsEMBL::ExternalData::BigFile::BigBedAdaptor;

sub summary_zmenu {
  # Way too many args, make OO.
  my ($self,$id,$r,$s,$e,$strand,$scalex,$width,$called_from_single) = @_;

  # Widen to incldue a few pixels around
  my $fudge = max(1,8/$scalex);
  
  # Round fudge to 1sf
  my $mult = "1"."0"x(length(int $fudge)-1);
  $fudge = int(($fudge/$mult)+0.5)*$mult;  
  my $mid = ($s+$e)/2;
  $s = int($mid - $fudge/2);
  $e = int($mid + $fudge/2);
  
  my $fgh = $self->hub->database('funcgen');
  my $rsa = $fgh->get_ResultSetAdaptor;
  my $rs = $rsa->fetch_by_dbID($id);
  my $bba = $self->bigbed($fgh,$id);
  my $ch3fa = $fgh->get_DNAMethylationFeatureAdaptor;

  my $sa = $self->hub->database('core')->get_SliceAdaptor;
  my $slice = $sa->fetch_by_toplevel_location($r)->seq_region_Slice;
  
  # Summarize features
  my ($astart,$astrand,$num,$num_this_strand,$tot_meth,$tot_read,$most_meth_perc,$least_meth_perc) = 
     (0,      0,       0,   0,               0,        0,        -1,             -1);
  my ($label);
  $bba->fetch_rows($slice->seq_region_name,$s,$e,sub {
    my @row = @_;
    my $f = Bio::EnsEMBL::Funcgen::DNAMethylationFeature->new( 
          -SLICE => $slice, 
            -SET => $rs, 
      -FILE_DATA => \@row, 
        -ADAPTOR => $ch3fa
    );
    my $p = $f->percent_methylation;
    $most_meth_perc = $p if($most_meth_perc==-1 or $most_meth_perc<$p);
    $least_meth_perc = $p if($least_meth_perc==-1 or $least_meth_perc>$p);
    $tot_meth += $f->methylated_reads;
    $tot_read += $f->total_reads;    
    $label = $f->display_label;
    my $right_strand = ($strand == $_[5]."1");
    $astart = $_[1]+1 if($right_strand or not $astart);
    $astrand = $_[5]."1" if($right_strand or not $astrand);
    $num++;
    $num_this_strand++ if($right_strand);
  });
  if($num==0) {
    # No features
    $self->caption("$label No features widthin ${fudge}bp");
    $self->add_entry({  type => "Overview",
                       label => "This track has no features near this point"});
  } elsif($num_this_strand==1 and not $called_from_single) {
    # One feature
    $self->single_base_zmenu($id,$r,$astart,$astrand,$width,$scalex);
  } elsif($num==1 and not $called_from_single) {
    # One feature
    $self->single_base_zmenu($id,$r,$astart,$astrand,$width,$scalex);
  } else {
    # Multiple features
    $self->caption("$label ${fudge}bp summary");
    my ($chr,) = split(/:/,$r);
    my $zoom_fudge = max($width/5,20);
    my ($zs,$ze) = map { int $_ } ($mid-$zoom_fudge/2,$mid+$zoom_fudge/2);
    $self->add_entry({ type => "Region Summary",
                       label => "Zoom using link below for individual feature details" });
    $self->add_entry({ type => "Location",
                       label => "$chr:$s-$e",
                       link => { r => "$chr:$s-$e" }});
    $self->add_entry({ type => "Feature Count",
                       label => $num });
    $self->add_entry({ type => "Methylated Reads",
                       label => sprintf("%d/%d",$tot_meth,$tot_read) });
    $self->add_entry({ type => "Min Methylation",
                       label => sprintf("%d%%",$least_meth_perc) });
    $self->add_entry({ type => "Max Methylation",
                       label => sprintf("%d%%",$most_meth_perc) });
  }
}

sub single_base_zmenu {
  my ($self,$id,$r,$s,$strand,$scalex,$width) = @_;
  
  # how far off can a user be due to scale? 8px or 1bp.
  my $fudge = max(1,8/$scalex);
  
  my $sa = $self->hub->database('core')->get_SliceAdaptor;
  my $slice = $sa->fetch_by_toplevel_location($r);

  my $fgh = $self->hub->database('funcgen');
  my $rsa = $fgh->get_ResultSetAdaptor;
  my $rs = $rsa->fetch_by_dbID($id);
  my $ch3fa = $fgh->get_DNAMethylationFeatureAdaptor;
    
  # Find nearest feature
  my $bba = $self->bigbed($fgh,$id);
  my @bigbedrow;
  my $closest = -1;
  $bba->fetch_rows($slice->seq_region_name,$s-$fudge,$s+1+$fudge,sub {
    my $dist = abs($_[1]+1-$s) + 0.5 * ($strand != $_[5]."1");
    if($closest == -1 or $dist < $closest) {
      @bigbedrow = @_;
      $closest = $dist;
    }
  });
  unless(@bigbedrow) {
    # user must have clicked on blank area
    $self->summary_zmenu($id,$r,$s,$s+1,$strand,$scalex,$width,1);
    return;
  }
  my $s = $bigbedrow[1]+1;
  my $e = $s+1;
  $slice = $sa->fetch_by_toplevel_location($r)->seq_region_Slice;

  # warn "got ".join(' ',@bigbedrow)."\n";
  my $f = Bio::EnsEMBL::Funcgen::DNAMethylationFeature->new( 
        -SLICE => $slice, 
          -SET => $rs, 
    -FILE_DATA => \@bigbedrow, 
      -ADAPTOR => $ch3fa
  );

  $self->caption($f->display_label." ".$r);
  $self->add_entry({ type => "Methylated Reads", 
                    label => sprintf("%d/%d (%d%%)\n",
                                     $f->methylated_reads,
                                     $f->total_reads,
                                     $f->percent_methylation)});
  $self->add_entry({ type => "Strand", label => $f->strand>0?'+ve':'-ve'});
  $self->add_entry({ type => "Context", label => $f->context}); 
  $self->add_entry({ type => "Cell type", label => $f->cell_type->name}); 
  $self->add_entry({ type => "Analysis method", label => $f->analysis->display_label}); 


}

sub bigbed {
  my ($self,$fgh,$id) = @_;
  
  my $rsa = $fgh->get_ResultSetAdaptor;
  my $rs = $rsa->fetch_by_dbID($id);
  
  my $bigbed_file = $rs->dbfile_data_dir;

  # Substitute path, if necessary. TODO: use DataFileAdaptor  
  my @parts = split(m!/!,$bigbed_file);
  $bigbed_file = join("/",$self->hub->species_defs->DATAFILE_BASE_PATH,
                          @parts[-5..-1]);

  return ( $self->{'_cache'}->{'bigbed_adaptor'}->{$bigbed_file} ||=
    Bio::EnsEMBL::ExternalData::BigFile::BigBedAdaptor->new($bigbed_file)
  );
}

sub content {
  my ($self) = @_;

  my $hub = $self->hub;
  my $id     = $hub->param('dbid');
  my $s      = $hub->param('click_start');
  my $e      = $hub->param('click_end');
  my $strand = $hub->param('strand');
  my $r      = $hub->param('r');
  my $scalex = $hub->param('scalex');
  my $width  = $hub->param('width');

  $r =~ s/:.*$/:$s-$e/;
  $s++ if($e==$s+2); # js quirk
  if($e>$s+1) {
    $self->summary_zmenu($id,$r,$s,$e,$strand,$scalex,$width,0);
  } else {
    $self->single_base_zmenu($id,$r,$s,$strand,$scalex,$width);
  }

}

1;
