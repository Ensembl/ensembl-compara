package EnsEMBL::Web::ZMenu::Methylation;

use strict;

use List::Util qw(max);
use List::MoreUtils qw(pairwise);

use base qw(EnsEMBL::Web::ZMenu);

use Bio::EnsEMBL::ExternalData::BigFile::BigBedAdaptor;

sub summary_zmenu {
  my ($self,$id,$r,$s,$e,$strand,$scalex,$called_from_single) = @_;

  # Widen to incldue a few pixels around
  my $fudge = max(1,4/$scalex);
  
  # Round fudge to 1sf
  my $mult = "1"."0"x(length(int $fudge)-1);
  $fudge = int(($fudge/$mult)+0.5)*$mult;  
  my $mid = ($s+$e)/2;
  $s = $mid - $fudge/2;
  $e = $mid + $fudge/2;
  

  my $fgh = $self->hub->database('funcgen');
  my $rsa = $fgh->get_ResultSetAdaptor;
  my $rs = $rsa->fetch_by_dbID($id);
  my $bba = $self->bigbed($fgh,$id);
  my $ch3fa = $fgh->get_DNAMethylationFeatureAdaptor;

  my $sa = $self->hub->database('core')->get_SliceAdaptor;
  my $slice = $sa->fetch_by_toplevel_location($r)->seq_region_Slice;
  
  # Summarize features
  my ($astart,$num,$tot_meth,$tot_read,$most_meth_perc,$least_meth_perc) = (0,0,0,-1,-1);
  my ($label);
  $bba->fetch_rows($slice->seq_region_name,$s,$e,sub {
    my @row = @_;
    my $f = Bio::EnsEMBL::Funcgen::DNAMethylationFeature->new( 
          -SLICE => $slice, 
            -SET => $rs, 
      -FILE_DATA => \@row, 
        -ADAPTOR => $ch3fa
    );
    next unless($strand == $row[5]."1");
    my $p = $f->percent_methylation;
    $most_meth_perc = $p if($most_meth_perc==-1 or $most_meth_perc<$p);
    $least_meth_perc = $p if($least_meth_perc==-1 or $least_meth_perc>$p);
    $tot_meth += $f->methylated_reads;
    $tot_read += $f->total_reads;    
    $label = $f->display_label;
    $astart = $_[1]+1;
    $num++;
  });
  if($num==0) {
    # No features
    $self->caption("$label No features"); # XXX or zero
    $self->add_entry({  type => "Overview",
                       label => "This track has no features near this point"});
  } elsif($num==1 and not $called_from_single) {
    # One feature
    warn "single\n";
    $self->single_base_zmenu($id,$r,$astart,$strand,$scalex);
  } else {
    # Multiple features
  
    $self->caption("$label multiple features"); # XXX or zero
    $self->add_entry({  type => "Overview",
                       label => "Too zoomed out to view methylation of individual bases"});
    my ($chr,) = split(/:/,$r);
    $self->add_entry({
      type  => 'Zoom',
      label => "zoom here",
      link => $self->hub->url({
        r => "$chr:$s-$e",
      }),
    });
    $self->add_entry({  type => "Summary",
                       label => sprintf(qq(
                          Region around cursor of size %dbp contains
                          %d bases with methylation data, totalling
                          %d reads in all, of which %d are methylated. The
                          lowest methylated read rate is %d%% 
                          and the highest %d%%),
                            $e-$s,$num,$tot_read,$tot_meth,
                            $least_meth_perc,$most_meth_perc)});
  }
}

sub single_base_zmenu {
  my ($self,$id,$r,$s,$strand,$scalex) = @_;
  
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
    my $dist = abs($_[1]+1-$s);
    if($strand == $_[5]."1" and ($closest == -1 or $dist < $closest)) {
      @bigbedrow = @_;
      $closest = $dist;
    }
  });
  unless(@bigbedrow) {
    # user must have clicked on blank area
    $self->summary_zmenu($id,$r,$s,$s+1,$strand,$scalex,1);
    return;
  }
  my $s = $bigbedrow[1]+1;
  my $e = $s+1;
  $r =~ s/:.*$/:$s-$e/;
  $slice = $sa->fetch_by_toplevel_location($r);

  #
  warn "got ".join(' ',@bigbedrow)."\n";
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
  $self->add_entry({ type => "Strand", label => $strand>0?'+ve':'-ve'});
  $self->add_entry({ type => "Context", label => $f->context}); 
  $self->add_entry({ type => "Cell type", label => $f->cell_type->name}); 
  $self->add_entry({ type => "Feature type", label => $f->feature_type->name}); 
  $self->add_entry({ type => "Analysis method", label => $f->analysis->logic_name}); 


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
  
  # Find nearest feature
  return Bio::EnsEMBL::ExternalData::BigFile::BigBedAdaptor->new($bigbed_file);
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

  $r =~ s/:.*$/:$s-$e/;
  $s++ if($e==$s+2); # js quirk
  if($e>$s+1) {
    $self->summary_zmenu($id,$r,$s,$e,$strand,$scalex,0);
  } else {
    $self->single_base_zmenu($id,$r,$s,$strand,$scalex);
  }

}

1;
