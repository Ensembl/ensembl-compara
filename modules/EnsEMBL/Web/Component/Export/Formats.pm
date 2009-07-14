package EnsEMBL::Web::Component::Export::Formats;

use strict;

use CGI qw(unescape);

use base 'EnsEMBL::Web::Component::Export';

sub content {
  my $self = shift;
  my $object = $self->object;
  
  my $form_action = $object->_url({ action => 'Configure', function => $object->function }, 1);
  my $slice = $object->param('slice');
  my $href = $object->param('base_url');
  
  my $form = $self->modal_form('export_output_configuration', $form_action->[0], { label => '< Back', method => 'get' });
  
  $form->add_fieldset;
  
  if ($slice) {
    my (@list, @formats, $note);
    
    if ($href) {
      @formats = (
        [ 'HTML', $href, 'HTML', ' rel="external"' ],
        [ 'Text', $href, 'Text', ' rel="external"' ],
        [ 'Compressed text (.gz)', $href, 'TextGz' ]
      );
      
      $note = 'Please choose the output format for your export';
    } else {
      @formats = (
        [ 'Sequence data',   $object->param('seq_file'),  '', ' rel="external"', ' [FASTA format]' ],
        [ 'Annotation data', $object->param('anno_file'), '', ' rel="external"', ' [pipmaker format]' ],
        [ 'Combined file',   $object->param('tar_file') ]
      );
      
      $note = 'Your export has been processed successfully. You can download the exported data by following the links below';
    }
        
    foreach (@formats) {
      my $url = CGI::unescape($_->[1] . ($_->[2] ? ";_format=$_->[2]" : ''));      
      push @list, qq{<a class="modal_close" href="$url"$_->[3]>$_->[0]</a>$_->[4]};
    }
    
    $form->add_notes({ class => undef, text => $note });
    $form->add_notes({ class => undef, list => \@list });
  } else { # User has input an invalid location
    $form->add_notes({ class => 'error', heading => 'Invalid Region', text => 'The region you have chosen does not exist. Please go back and try again' });
  }
  
  $form->add_element(type => 'Hidden', name => $_, value => $form_action->[1]->{$_}) for keys %{$form_action->[1]};
  
  return '<h2>Export Configuration - Output Format</h2>' . $form->render;
}

1;
