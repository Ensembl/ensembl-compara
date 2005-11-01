package EnsEMBL::Web::Component::Help;

use EnsEMBL::Web::Component;
use EnsEMBL::Web::Form;

our @ISA = qw( EnsEMBL::Web::Component);
use strict;
use warnings;
no warnings "uninitialized";

use constant 'HELPVIEW_WIN_ATTRIBS' => "width=700,height=550,resizable,scrollbars";
use constant 'HELPVIEW_IMAGE_DIR'   => "/img/help";

sub form_thankyou {
  my($panel,$object) = @_;
  my $sitetype = ucfirst(lc($object->species_defs->ENSEMBL_SITETYPE)) || 'Ensembl';
  $panel->print(qq(
<p>
 Your message was successfully sent to the $sitetype Site Helpdesk Administration Team. They will get back to you in due course.
</p>
<p>
 Helpdesk
</p>));
  return 1;
}

sub first_page {
  my($panel,$object) = @_;
  $panel->print(qq(
<p>
  To start searching, either enter your keywords in
  the look up box above, or select one of the links
  on the left hand side.
</p>));
  return 1;
}

sub multi_match {
  my($panel,$object) = @_;
  $panel->print(qq(
  <p>Your search for "@{[$object->param('kw')]}" is found in the following entries:</p>
  <ul>));
  foreach( @{$object->results}) {
    $panel->printf( qq(\n    <li><a href="%s">%s</a></li>), $object->_help_URL($_->{'keyword'}), $_->{'title'} );
  } 
  $panel->print(qq(\n</ul>));
  return 1;
}

sub single_match {
  my($panel,$object) = @_;
  $panel->print( link_mappings( $object, $object->results->[0]{'content'} ) );
}

sub single_match_failure {
  my($panel,$object) = @_;
  $panel->print(qq(
    <p>Your search for "@{[$object->param('kw')]}" found no matches.</p>
  ));
  return 1;
}

sub link_mappings {
  my $object = shift;
  my $content = shift;
     $content =~ s/HELP_(.*?)_HELP/$object->_help_URL("$1")/mseg;
  my $replace = HELPVIEW_IMAGE_DIR;
     $content =~ s/IMG_(.*?)_IMG/$replace\/$1/mg;
  return $content;
}

sub help_form {
  my( $panel, $object ) =@_;
  $panel->print( $panel->form( 'help_form' )->render );
  return 1;
}

sub help_response {

}

sub help_form_form {
  my( $panel, $object ) = @_;
  my $script = $object->script;

  my $form = EnsEMBL::Web::Form->new( 'helpform', "/@{[$object->species]}/$script", 'post' );

  $form->add_element(
    'type'     => 'String',
    'required' => 'yes',
    'name'     => 'name',
    'label'    => 'Your name',
    'value'    => $object->param('name')
  );
  $form->add_element(
    'type'     => 'Email',
    'required' => 'yes',
    'name'     => 'email',
    'label'    => 'Your email',
    'value'    => $object->param('email')
  );
  my @LISTS = (
    [ 'Helpdesk feedback' =>
      'Gene structure',       'Mapping / Markers',
      'Gene positioning',     'Gene prediction',
      'Protein analysis',     'Blast',
      'SSAHA',                'BioMart',
      'Website installation', 'Database installation',
      'Broken link',          'Other general' ],
    [ 'Website feedback'  =>
      'Web problem',          'Web suggestion',
      'Other website' ]
  );
  my $options = [];
  foreach my $LIST (@LISTS) {
    my( $GROUP, @L ) = @$LIST;
    foreach( @L ) { push @$options, { 'group'=>$GROUP, 'name' => $_, 'value' => $_ }; }
  }
  $form->add_element(
    'firstline' => 'Select problem type',
    'type'   => 'DropDown',
    'select' => 'select',
    'name'   => 'category',
    'label'  => 'Problem / Query',
    'values' => $options,
    'value'  => $object->param( 'category' ),
    'required' => 'yes',
  );

  $form->add_element(
    'type'   => 'Text',
    'name'   => 'comments',
    'label'  => 'Details/comments',
    'value'  => $object->param( 'comments' ),
    'required' => 'yes',
  );
  $form->add_element( 'type'  => 'Hidden', 'name' => 'ref', 'value' => $object->referer );
  $form->add_element( 'type'  => 'Hidden', 'name' => 'kw',  'value' => $object->param('kw') );
  $form->add_element( 'type'  => 'Hidden', 'name' => 'action', 'value' => 'submit' );
  $form->add_element( 'type'   => 'Submit', 'value'  => 'Submit');
  return $form;
}

1;
