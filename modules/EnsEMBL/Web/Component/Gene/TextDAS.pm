package EnsEMBL::Web::Component::Gene::TextDAS;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::RegObj; # exports web registry
use EnsEMBL::Web::Document::HTML::TwoCol;
use Bio::EnsEMBL::ExternalData::DAS::Coordinator;
use EnsEMBL::Web::Document::SpreadSheet;

use CGI qw(unescapeHTML);
use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  return undef;
}

sub content {
  my $self = shift;
  
  # The proxy object we're operating on (gene/translation):
  my $object = $self->object;
  
  # The DAS source this page represents:
  my $logic_name = $object->parent->{'ENSEMBL_FUNCTION'} ||
                   $ENV{'ENSEMBL_FUNCTION'};

  return $self->_error( 'No DAS source specified',
    'No parameter passed!' 
  ) unless $logic_name;
  
  my $source = $ENSEMBL_WEB_REGISTRY->get_das_by_logic_name( $logic_name );
  
  return $self->_error( sprintf( 'DAS source "%s" specified does not exist', $logic_name ),
    'Cannot find the specified DAS source key supplied' 
  ) unless $source;

  my $engine = Bio::EnsEMBL::ExternalData::DAS::Coordinator->new(
    -sources => [ $source ],
    -proxy   => $object->species_defs->ENSEMBL_WWW_PROXY,
    -noproxy => $object->species_defs->ENSEMBL_NO_PROXY,
    -timeout => $object->species_defs->ENSEMBL_DAS_TIMEOUT
  );
  
  my $table = EnsEMBL::Web::Document::HTML::TwoCol->new();
  $table->add_row( 'Description', $source->description );#, 1 );
  if ( my $homepage = $source->homepage ) {
    $table->add_row( 'Homepage', qq(<a href="$homepage">$homepage</a>) );
  }
  
  my $html = $table->render;
  
  # Perform DAS requests...
  my $data = $engine->fetch_Features( $object->Obj )->{$logic_name};
  
  # Check for source errors (bad configs)
  my $source_err = $data->{'source'}->{'error'};
  if ( $source_err ) {
    $html .= $self->_error('Error', $source_err);
    return $html;
  }
  
  # Request could be for several segments
  for my $coord_key ( keys %{ $data->{'features'} } ) {
    
    my $err = $data->{'features'}->{$coord_key}->{'error'};
    my $url = $data->{'features'}->{$coord_key}->{'url'};
    my $cs  = $data->{'features'}->{$coord_key}->{'coord_system'};
    
    # Start of a new section
    $html .= sprintf qq(<h3>%s [<a href="%s">view DAS response</a>]</h3>\n),
                     $cs->label, $url;
    
    if ( $err ) {
      $html .= $self->_error('Error', $err);
      next;
    }
    
    # We only want nonpositional features
    my @features = grep {
      !$_->start && !$_->end
    } @{ $data->{'features'}->{$coord_key}->{'objects'} };
    
    # Did we get anything useful?
    if (! scalar @features ) {
      $html .= qq(<p>No annotations.</p>\n);
      next;
    }
    
    # TODO: do this in an OO way?
    my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px','triangle'=>1} );
    $table->add_columns(
      { 'key' => 'type',  'title' => 'Type',  'width' => '15%' },
      { 'key' => 'label', 'title' => 'Label', 'width' => '15%' },
      { 'key' => 'notes', 'title' => 'Notes', 'width' => '70%' }
    );
    for my $f ( sort { $a->type_label cmp $b->type_label } @features ) {
      my $note = join '<br/>', @{ $f->notes };
      (my $lh = ucfirst($f->type_label)) =~ s/_/ /g;
      $table->add_row({
        'type' => $lh, 'label' => $f->display_label, 'notes' => $note
      });
    }
    $html .= $table->render;
  }

  # Only unescape content served from "preconfigured" DAS sources
  # TODO: convert this to a detainting process
  return $source->is_external ? $html : CGI::unescapeHTML( $html );
}

1;

