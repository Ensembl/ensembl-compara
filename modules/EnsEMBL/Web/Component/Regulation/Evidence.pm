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

  my $focus_attributes =  $object->regulation->get_focus_attributes; 
  unless ($focus_attributes) {
    my $html = "<p>There are no evidence for this regulatory feature </p>";
    return $html;
  }

  my $evidence_attributes = $object->regulation->get_nonfocus_attributes;
  my %nonfocus_data;
  foreach (@$evidence_attributes) {
    my $unique_feature_set_id =  $_->feature_set->feature_type->name .':'.$_->feature_set->cell_type->name . ':' .$_->start; 
    my $histone_mod = substr($unique_feature_set_id, 0, 2);
    unless ($histone_mod =~/H\d/){ $histone_mod = 'Other';}
    $nonfocus_data{$histone_mod} = {} unless exists $nonfocus_data{$histone_mod};
    $nonfocus_data{$histone_mod}{$unique_feature_set_id} = $_;
  }



  my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' =>'1em 0px'});
  $table->add_columns(
    {'key' => 'type',     'title' => 'Evidence type', 'align' => 'left'},
    {'key' => 'location', 'title' => 'Location',      'align' => 'left'},
    {'key' => 'feature',  'title' => 'Feature name',  'align' => 'left'},
    {'key' => 'cell',     'title' => 'Cell type',     'align' => 'left'}
  ); 

  my @rows;
  my $row = {'type' => 'Core'};
  $table->add_row($row); 




  foreach (@$focus_attributes){ 
    my $location = $_->slice->seq_region_name .":".$_->start ."-" . $_->end;
    my $url = $object->_url({'type' => 'Location', 'action' => 'View', 'r' => $location  });
    my $location_link = qq(<a href=$url>$location</a>);
    my $cell_type = $_->feature_set->cell_type->name;
    my $feature_type = $_->feature_set->feature_type->name;

    my $row = {
      'location'  => $location_link,
      'feature'   => $feature_type,
      'cell'      => $cell_type 
    };
    push @rows, $row;
  }

  foreach my $type ( sort keys %nonfocus_data ){
    my $row  = {'type' => $type};
    push (@rows, $row); 
    my $data = $nonfocus_data{$type};
    foreach (sort keys %$data) {
      my $f= $data->{$_};
      my $location = $f->slice->seq_region_name .":".$f->start ."-" . $f->end;
      my $url = $object->_url({'type' => 'Location', 'action' => 'View', 'r' => $location  });
      my $location_link = qq(<a href=$url>$location</a>);
      my $cell_type = $f->feature_set->cell_type->name;
      my $feature_type = $f->feature_set->feature_type->name;

      my $row = {
        'location'  => $location_link,
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
