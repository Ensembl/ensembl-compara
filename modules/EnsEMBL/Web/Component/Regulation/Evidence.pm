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
  my $attributes =  $object->regulation->get_focus_attributes; 
  unless ($attributes) {
    my $html = "<p>There are no evidence for this regulatory feature </p>";
    return $html;
  }

  my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' =>'1em 0px'});
  $table->add_columns(
    {'key' => 'type',     'title' =>  '',             'align' => 'left'},
    {'key' => 'location', 'title' => 'Location',      'align' => 'left'},
    {'key' => 'feature',  'title' => 'Feature name',  'align' => 'left'},
    {'key' => 'cell',     'title' => 'Cell type',     'align' => 'left'}
  ); 

  my @rows;
  my $row = {'type' => 'Focus'};
  $table->add_row($row); 

  foreach (@$attributes){
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

  foreach (@rows){
    $table->add_row($_);
  }

  return $table->render;
}

1;
