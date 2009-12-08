=head1 NAME

EnsEMBL::Web::Component::Server

=head1 SYNOPSIS

Show information about the webserver

=head1 DESCRIPTION

A series of functions used to render server information

=head1 CONTACT

Contact the EnsEMBL development mailing list for info <ensembl-dev@ebi.ac.uk>

=cut

package EnsEMBL::Web::Component::Server::tree;

use HTML::Entities qw(encode_entities);
use EnsEMBL::Web::Form;
use Bio::EnsEMBL::ColourMap;
our $cm;
use base qw(EnsEMBL::Web::Component);
use strict;
use warnings;
no warnings "uninitialized";

sub display_node {
  my($self,$x,$depth) = @_;
  my $ret = '';
  if( ref( $x ) eq 'HASH' ) {           ## HASH REF....
    $ret .= '<table class="nested" style="border:1px solid red">';
    foreach( sort keys %$x ) {
      $ret .= sprintf '<tr><th>%s</th><td>%s</td></tr>', encode_entities( $_ ), $self->display_node( $x->{$_}, $depth + 1 );
    }
    $ret .= '</table>';
  } elsif( ref( $x ) eq 'ARRAY' ) {     ## ARRAY REF....
    my $C = 0;
    $ret .= '<table class="nested" style="border:1px solid blue">';
    foreach( @$x ) {
      $ret .= sprintf '<tr><th>%d</th><td>%s</td></tr>', $C++, $self->display_node( $_, $depth + 1 );
    }
    $ret .= '</table>';
  } else { ## SCALAR
    $ret .= sprintf '<div style="border:1px solid green">%s</div>', encode_entities( $x );
  }
  return $ret;
}

sub tree_form {
  my($panel,$object) = @_;
  my $form = EnsEMBL::Web::Form->new( 'tree', '/'.$object->species.'/tree', 'get' );
  $form->add_element(
    'type'  => 'Information',
    'value' => '<p>Select the file you wish to look at</p>'
  );
  $form->add_element(
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'file',
    'label'    => 'File',
    'values'   => [ map( { { 'value' => $_, 'name' => $_ } } $object->get_all_packed_files )],
    'value'    => $object->param('file')
  );

  $form->add_element( 'type' => 'Submit', 'value' => 'Change' );
  return $form;

}

sub content {
  my $self = shift;
  my $object = $self->object;
  return sprintf( '<p>contents of %s.packed</p>', $object->param('file') ).
    $self->display_node( $object->unpack_db_tree, 0 );
}
=head2 name

  Arg [panel]:  EnsEMBL::Web::Document::Panel::Information;
  Arg [object]: EnsEMBL::Web::Proxy::Object({Static});
  Description: Add a row to an information panel showing the release version and site type

=cut

1;
