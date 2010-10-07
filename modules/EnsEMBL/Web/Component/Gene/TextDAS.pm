# $Id$

package EnsEMBL::Web::Component::Gene::TextDAS;

use strict;

use HTML::Entities qw(encode_entities decode_entities);
use XHTML::Validator;

use Bio::EnsEMBL::ExternalData::DAS::Coordinator;

use EnsEMBL::Web::Document::HTML::TwoCol;
use EnsEMBL::Web::Document::SpreadSheet;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
  $self->{'validator'}          = new XHTML::Validator('extended');
  $self->{'validate_error'}     = 'Data provided by this DAS source contains HTML markup, but it contains errors or has dangerous content. As a security precaution it has not been processed.';
  $self->{'timeout_multiplier'} = 3;
}

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $logic_name   = $hub->referer->{'ENSEMBL_FUNCTION'} || $hub->function; # The DAS source this page represents

  return $self->_error('No DAS source specified', 'No parameter passed!', '100%') unless $logic_name;
  
  my $source = $hub->get_das_by_logic_name($logic_name);
  
  return $self->_error(qq{DAS source "$logic_name" specified does not exist}, 'Cannot find the specified DAS source key supplied', '100%') unless $source;
  
  my $desc     = $source->description;
  my $homepage = $source->homepage;
  my $table    = new EnsEMBL::Web::Document::HTML::TwoCol;
  
  $table->add_row('Description', $desc, 1);
  $table->add_row('Homepage', qq(<a href="$homepage">$homepage</a>), 1) if $homepage;
  
  my $html = $table->render;
  
  my $engine = new Bio::EnsEMBL::ExternalData::DAS::Coordinator(
    -sources => [ $source ],
    -proxy   => $species_defs->ENSEMBL_WWW_PROXY,
    -noproxy => $species_defs->ENSEMBL_NO_PROXY,
    -timeout => $species_defs->ENSEMBL_DAS_TIMEOUT * $self->{'timeout_multiplier'}
  );
  
  # Perform DAS requests
  my $data = $engine->fetch_Features($self->object->Obj)->{$logic_name};
  
  # Check for source errors (bad configs)
  my $source_err = $data->{'source'}->{'error'};
  
  if ($source_err) {
    $html .= $self->_error('Error', $source_err, '100%');
    return $html;
  }
  
  # Request could be for several segments
  for my $segment (keys %{$data->{'features'}}) {
    my $errored = 0;
    my $err     = $data->{'features'}->{$segment}->{'error'};
    my $url     = $data->{'features'}->{$segment}->{'url'};
    my $cs      = $data->{'features'}->{$segment}->{'coord_system'};
    
    # Start of a new section
    $html .= sprintf qq{<h3>%s %s [<a href="%s">view DAS response</a>]</h3>\n}, $cs->label, $segment, $url;
    
    if ($err) {
      $html .= $self->_error('Error', $err, '100%');
      next;
    }
    
    # We only want nonpositional features
    my @features = @{$data->{'features'}->{$segment}->{'objects'}};
    
    my $num_positional_features    = 0;
    my $num_nonpositional_features = 0;
    
    my $table2 = new EnsEMBL::Web::Document::SpreadSheet([], [], { margin => '1em 0px', triangle => 1 });
    
    $table2->add_columns(
      { key => 'type',  title => 'Type',  width => '15%' },
      { key => 'label', title => 'Label', width => '15%' },
      { key => 'notes', title => 'Notes', width => '70%' }
    );
    
    foreach my $f (sort { $a->type_label cmp $b->type_label || $a->display_label cmp $b->display_label } @features) {
      if ($f->start || $f->end) {
        $num_positional_features++;
        next;
      }
      
      $num_nonpositional_features++;
      
      my @notes = ();
      my @links = ();
      
      foreach my $raw (@{$f->notes}) {
        # OK, we apparently need to support non-spec HTML embedded in notes,
        # so let's decode it.
        my ($note, $warning) = $self->_decode_and_validate($raw);
        
        # Show the error, but only show one at a time as it could get spammy
        if ($warning && !$self->{'errored'}) {
          $self->{'errored'} = 1;
          $html .= $self->_warning('Problem parsing note', "$self->{'validate_error'}$warning", '100%');
        }
        
        push @notes, "<div>$note</div>";
      }
      
      foreach my $link (@{$f->links}) {
        my $raw         = $link->{'href'};
        my ($cdata, $w) = $self->_decode_and_validate($link->{'txt'});
        
        # We don't expect embedded HTML here so don't need to decode, but still
        # need to validate to protect against XSS...
        my ($href, $warning) = $self->_validate($raw);
        
        # Show the error, but only show one at a time as it could get spammy
        if ($warning && !$self->{'errored'}) {
          $self->{'errored'} = 1;
          $html .= $self->_warning('Problem parsing link', "$self->{'validate_error'}$warning", '100%');
        }
        
        push @links, sprintf '<div><a href="%s">%s</a></div>', $href, $cdata;
      }
      
      my $text = join "\n", @notes, @links;
      
      (my $lh = ucfirst $f->type_label) =~ s/_/ /g;
      my ($display_label , $w) = $self->_decode_and_validate($f->display_label);
      
      $table2->add_row({ type => $lh, label => $display_label, notes => $text });
    }
    
    # Did we get anything useful?
    if ($num_positional_features == 0 && $num_nonpositional_features == 0) {
      $html .= "<p>No annotations.</p>\n";
    } else {
      if ($num_positional_features == 1) {
        $html .= "<p>There was 1 non-text annotation. To view it, enable the DAS source on a graphical view.</p>\n";
      } elsif ($num_positional_features > 1) {
        $html .= "<p>There were $num_positional_features non-text annotations. To view these, enable the DAS source on a graphical view.</p>\n";
      }
      
      $html .= $table2->render if $num_nonpositional_features > 0;
    }
  }
  
  return $html;
}

sub _decode_and_validate {
  my ($self, $text) = @_;
  return $self->_validate(decode_entities($text));
}

sub _validate {
  my ($self, $text) = @_;
  
  # Check for naughty people trying to do XSS...
  if (my $warning = $self->{'validator'}->validate($text)) {
    $text = encode_entities($text);
    return ($text, $warning);
  }
  
  return ($text, undef);
}

1;

