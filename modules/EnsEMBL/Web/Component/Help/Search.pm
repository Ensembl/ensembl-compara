package EnsEMBL::Web::Component::Help::Search;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Help);
use CGI qw(escapeHTML);
use EnsEMBL::Web::Form;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $sitename = $object->species_defs->ENSEMBL_SITETYPE;
  my $html = qq(<h3>Search $sitename Help</h3>);

  my $form = EnsEMBL::Web::Form->new( 'contact', "/Help/DoSearch", 'get' );

  $form->add_element(
    'type'    => 'String',
    'name'    => 'string',
    'label'   => 'Search for',
  );

  $form->add_element(
    'type'    => 'CheckBox',
    'name'    => 'hilite',
    'label'   => 'Highlight search term(s)',
  );

  $form->add_element(
    'type'    => 'Hidden',
    'name'    => '_referer',
    'value'   => $object->param('_referer'),
  );

  $form->add_element(
    'type'    => 'Submit',
    'name'    => 'submit',
    'value'   => 'Go',
    'class'   => 'modal_link',
  );

  $html .= $form->render;

  $html .= qq(
  <h4>Search Tips</h4>
<p>Ensembl Help now uses MySQL full text searching. This performs a case-insensitive natural language search
on the content of the help database. This gives better results than a simple string search, with some caveats:</p>
<ul>
<li>Words that occur in more than 50% of the records are ignored.</li>
<li>Wildcards such as '%' (zero or one occurences of any character) and '_' (exactly one character) are no longer available.</li>
</ul>
);

  return $html;
}

1;
