package EnsEMBL::Web::Component::Gene::TextDAS;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::RegObj; # exports web registry
use EnsEMBL::Web::Document::HTML::TwoCol;
use Bio::EnsEMBL::ExternalData::DAS::Coordinator;
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
  my $logic_name = $ENV{'ENSEMBL_FUNCTION'}|| 'DS_409' || die "Bad configuration: unknown DAS source";
  
  my $source = $ENSEMBL_WEB_REGISTRY->get_das_by_logic_name( $logic_name );
  my $engine = Bio::EnsEMBL::ExternalData::DAS::Coordinator->new(
    -sources => [ $source ],
    -proxy   => $object->species_defs->ENSEMBL_WWW_PROXY,
    -noproxy => $object->species_defs->ENSEMBL_NO_PROXY,
    -timeout => $object->species_defs->ENSEMBL_DAS_TIMEOUT
  );
  
  my $table = EnsEMBL::Web::Document::HTML::TwoCol->new();
  $table->add_row( 'Description', $source->description );
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
  for my $segment ( keys %{ $data->{'features'} } ) {
    
    my $err = $data->{'features'}->{$segment}->{'error'};
    my $url = $data->{'features'}->{$segment}->{'url'};
    my $cs  = $data->{'features'}->{$segment}->{'coord_system'};
    
    # Start of a new section
    $html .= sprintf qq(<h3>%s (%s) [<a href="%s">view DAS response</a>]</h3>\n),
                     $segment, $cs->label, $url;
    
    if ( $err ) {
      $html .= $self->_error('Error', $err);
      next;
    }
    
    # We only want nonpositional features
    my @features = grep {
      !$_->start && !$_->end
    } @{ $data->{'features'}->{$segment}->{'objects'} };
    
    # Did we get anything useful?
    if (! scalar @features ) {
      $html .= qq(<p>No annotations.</p>\n);
      next;
    }
    
    # TODO: do this in an OO way?
    $html .= "<table>\n";
    $html .= "<tr><th>Type</th><th>Label</th><th>Notes</th></tr>\n";
    for my $f ( sort { $a->type_label cmp $b->type_label } @features ) {
      my $note = join '<br/>', @{ $f->notes };
      $html .= sprintf "<tr><td>%s</td><td>%s</td><td>%s</td></tr>\n",
        $f->type_label, $f->display_label, $note;
    }
    $html .= "</table>\n";
  }

$html.= $source->category;

  # Only unescape content served from "preconfigured" DAS sources
  # TODO: convert this to a detainting process
  return $source->is_external ? $html : CGI::unescapeHTML( $html );
}

1;

