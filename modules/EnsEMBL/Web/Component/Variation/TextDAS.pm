# $Id$

package EnsEMBL::Web::Component::Variation::TextDAS;

use strict;

use Bio::EnsEMBL::ExternalData::DAS::Coordinator;

use HTML::Entities qw(encode_entities decode_entities);
use XHTML::Validator;

use EnsEMBL::Web::Document::HTML::TwoCol;

use base qw(EnsEMBL::Web::Component::Variation);

our $VALIDATE_ERROR = 'Data provided by this DAS source contains HTML markup, '.
                      'but it contains errors or has dangerous content. As a '.
                      'security precaution it has not been processed. ';
# temporary solution to arrayexpress being so slow...
our $TIMEOUT_MULTIPLIER = 3;

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
  $self->{'validator'} = new XHTML::Validator('extended');
}

sub _das_query_object {
  my $self = shift;
  return $self->object->Obj;
}

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $object       = $self->object;
  my $species_defs = $hub->species_defs;
  
  # The DAS source this page represents:
  my $logic_name = $hub->referer->{'ENSEMBL_FUNCTION'} || $hub->function;

  return $self->_error('No DAS source specified', 'No parameter passed!', '100%') unless $logic_name;
  
  my $source = $hub->get_das_by_logic_name($logic_name);
  
  return $self->_error(qq{DAS source "$logic_name" specified does not exist}, 'Cannot find the specified DAS source key supplied', '100%') unless $source;
  
  my $html = '';
  
  # Some sources (e.g. UniProt) have taken to using HTML descriptions
  # But we don't really want to support this everywhere on the site
  my $desc = $source->description;
  
  my $table = new EnsEMBL::Web::Document::HTML::TwoCol;
  $table->add_row('Description', $desc, 1);
  
  if (my $homepage = $source->homepage) {
    $table->add_row('Homepage', qq{<a href="$homepage">$homepage</a>}, 1);
  }
  
  $html .= $table->render;
  my $query_object = $self->_das_query_object;
  
  my $engine = new Bio::EnsEMBL::ExternalData::DAS::Coordinator(
    -sources => [ $source ],
    -proxy   => $species_defs->ENSEMBL_WWW_PROXY,
    -noproxy => $species_defs->ENSEMBL_NO_PROXY,
    -timeout => $species_defs->ENSEMBL_DAS_TIMEOUT * $TIMEOUT_MULTIPLIER
  );
  # Perform DAS requests...
  my $data = $engine->fetch_Features( $query_object )->{$logic_name};
  
  # Check for source errors (bad configs)
  my $source_err = $data->{'source'}->{'error'};
  if ( $source_err ) {
    $html .= $self->_error('Error', $source_err, '100%');
    return $html;
  }
  
  # Request could be for several segments
  for my $segment ( keys %{ $data->{'features'} } ) {
    
    my $errored = 0;
    my $err = $data->{'features'}->{$segment}->{'error'};
    my $url = $data->{'features'}->{$segment}->{'url'};
    my $cs  = $data->{'features'}->{$segment}->{'coord_system'};
    
    # Start of a new section
    $html .= sprintf qq(<h3>%s %s [<a href="%s">view DAS response</a>]</h3>\n),
                     $cs->label, $segment, $url;
    
    if ( $err ) {
      $html .= $self->_error('Error', $err, '100%');
      next;
    }
    
    # We only want nonpositional features
    my @features = @{ $data->{'features'}->{$segment}->{'objects'} };
    
    my $num_positional_features = 0;
    my $num_nonpositional_features = 0;
    
    my $table = $self->new_table([], [], { margin => '1em 0px', triangle => 1 });
    $table->add_columns(
      { 'key' => 'type',  'title' => 'Type',  'width' => '15%' },
#      { 'key' => 'label', 'title' => 'Label', 'width' => '15%' },
      { 'key' => 'notes', 'title' => 'Notes', 'width' => '70%' }
    );
    
    for my $f ( sort { $a->type_label cmp $b->type_label || $a->display_label cmp $b->display_label } @features ) {
      
      if ($f->start || $f->end) {
        $num_positional_features++;
        next;
      }
      
      $num_nonpositional_features++;
      
      my @notes = ();
      my @links = ();

      for my $raw ( @{ $f->notes } ) {
        # OK, we apparently need to support non-spec HTML embedded in notes,
        # so let's decode it.
        my ( $note, $warning ) = $self->_decode_and_validate( $raw );
        # Show the error, but only show one at a time as it could get spammy
        if ($warning && !$self->{'errored'}) {
          $self->{'errored'} = 1;
          $html .= $self->_warning('Problem parsing note',
                                   "$VALIDATE_ERROR$warning",
                                   '100%');
        }
        push @notes, "<div>$note</div>";
      }
      
      for my $link ( @{ $f->links } ) {
        my $raw  = $link->{'href'};
        my $cdata = $link->{'txt'};
        # We don't expect embedded HTML here so don't need to decode, but still
        # need to validate to protect against XSS...
        my ( $href, $warning ) = $self->_validate( $raw );
        # Show the error, but only show one at a time as it could get spammy
        if ($warning && !$self->{'errored'}) {
          $self->{'errored'} = 1;
          $html .= $self->_warning('Problem parsing link',
                                   "$VALIDATE_ERROR$warning",
                                   '100%');
        }
        push @links, sprintf '<div><a href="%s">%s</a></div>', $href, $cdata;
      }
      
      my $text = join "\n", @notes, @links;
      
      (my $lh = ucfirst($f->type_label)) =~ s/_/ /g;
      $table->add_row({
#        'type' => $lh, 'label' => $f->display_label, 'notes' => $text
        'type' => $lh,  'notes' => $text
      });
    }
    
    # Did we get anything useful?
    if ($num_positional_features == 0 && $num_nonpositional_features == 0) {
      $html .= qq(<p>No annotations.</p>\n);
    } else {
      if ($num_positional_features == 1) {
        $html .= qq(<p>There was 1 non-text annotation. To view it, enable the DAS source on a graphical view.</p>\n);
      }
      elsif ($num_positional_features > 1) {
        $html .= qq(<p>There were $num_positional_features non-text annotations. To view these, enable the DAS source on a graphical view.</p>\n);
      }
      if ($num_nonpositional_features > 0) {
        $html .= $table->render;
      }
    }
  }
  
  return $html;
}

sub _decode_and_validate {
  my ( $self, $text ) = @_;
  return $self->_validate( decode_entities( $text ) );
}

sub _validate {
  my ( $self, $text ) = @_;
  
  # Check for naughty people trying to do XSS...
  if ( my $warning = $self->{'validator'}->validate( $text ) ) {
    $text = encode_entities( $text );
    return ( $text, $warning );
  }
  
  return ( $text, undef );
}

1;

