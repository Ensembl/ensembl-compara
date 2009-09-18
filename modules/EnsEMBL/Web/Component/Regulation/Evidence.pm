package EnsEMBL::Web::Component::Regulation::Evidence;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Regulation);
use CGI qw(escapeHTML);


sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my %evidence;

  my $focus_attributes =  $object->regulation->get_focus_attributes; 
  unless ($focus_attributes) {
    my $html = "<p>There is no evidence for this regulatory feature </p>";
    return $html;
  }
  foreach ( @$focus_attributes){
    $evidence{'Core'} = [] unless exists $evidence{'Core'};
    push @{$evidence{'Core'}}, $_;
  }



  my $evidence_attributes = $object->regulation->get_nonfocus_attributes;
  my %nonfocus_data;
  foreach (@$evidence_attributes) {
    my $unique_feature_set_id =  $_->feature_set->feature_type->name .':'.$_->feature_set->cell_type->name . ':' .$_->start; 
    my $histone_mod = substr($unique_feature_set_id, 0, 2);
    unless ($histone_mod =~/H\d/){ $histone_mod = 'Other';}
    $evidence{$histone_mod} = [] unless exists $evidence{$histone_mod};
    push @{$evidence{$histone_mod}}, $_;
  }



  my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' =>'1em 0px'});
  $table->add_columns(
    {'key' => 'type',     'title' => 'Evidence type', 'align' => 'left'},
    {'key' => 'location', 'title' => 'Location',      'align' => 'left'},
    {'key' => 'feature',  'title' => 'Feature name',  'align' => 'left'},
    {'key' => 'cell',     'title' => 'Cell type',     'align' => 'left'}
  ); 

  my @rows;
  my %seen_evidence_type;

  foreach (sort keys %evidence ){ 
    my $features = $evidence{$_};  
    foreach my $f ( sort { $a->start <=> $b->start } @$features){  
      my $location = $f->slice->seq_region_name .":".$f->start ."-" . $f->end;
      my $cell_type = $f->feature_set->cell_type->name;
      my $feature_type = $f->feature_set->feature_type->name;
      my $evidence_type;
      if (exists $seen_evidence_type{$_} ){ 
        $evidence_type = '';    
      } else {
        $evidence_type = $_;
        if ($evidence_type =~/H\d/){$evidence_type = 'Histone '. $evidence_type;} 
        $seen_evidence_type{$_} =1;
      }

      my $row = {
      'type'      => $evidence_type,
      'location'  => $location,
      'feature'   => $feature_type,
      'cell'      => $cell_type 
      };
      push @rows, $row;
    }
  }

  foreach (@rows){
    $table->add_row($_);
  }

  return $table->render;
}


1;
