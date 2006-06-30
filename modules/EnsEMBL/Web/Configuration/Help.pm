package EnsEMBL::Web::Configuration::Help;

use strict;
use EnsEMBL::Web::Configuration;
use EnsEMBL::Web::Wizard::Help;
#use Mail::Mailer;

our @ISA = qw( EnsEMBL::Web::Configuration );

sub helpview {
  my $self = shift;
  my $object = $self->{object};

  ## Configure masthead, left hand menu, etc.
  my $sitetype = ucfirst(lc($object->species_defs->ENSEMBL_SITETYPE)) || 'Ensembl';
  $self->set_title( "$sitetype HelpView" );
  $self->{'page'}->close->style = 'help';
  $self->{'page'}->close->URL   = "/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}";
  $self->{'page'}->close->kw    = $object->param('kw');
  $self->{'page'}->helplink->label  = 'Contact helpdesk';
  $self->{'page'}->helplink->action = 'form';
  $self->{'page'}->helplink->kw     = $object->param('kw');
  $self->{'page'}->helplink->ref    = $object->referer;

  $self->{'page'}->menu->add_block( '___', 'bulleted', 'Help with help!' );
  $self->{'page'}->menu->add_entry( '___', 'href' => $object->_help_URL( {'kw'=>'helpview'} ), 'text' => 'General' ) ;
  $self->{'page'}->menu->add_entry( '___', 'href' => $object->_help_URL( {'kw'=>'helpview#searching'} ), 'text' => 'Full text search' );

  ## the "helpview" wizard uses 7 nodes: intro, do search, multiple results, single result, 
  ## no result, send email and acknowledgement
  my $wizard = EnsEMBL::Web::Wizard::Help->new($object);
  $wizard->add_nodes([qw(hv_intro hv_search hv_multi hv_single hv_contact hv_email hv_thanks)]);
  $wizard->default_node('hv_intro');

  ## chain the nodes together
  $wizard->chain_nodes([
          ['hv_intro'=>'hv_search'],
          ['hv_search'=>'hv_multi'],
          ['hv_search'=>'hv_single'],
          ['hv_search'=>'hv_contact'],
          ['hv_contact'=>'hv_email'],
          ['hv_email'=>'hv_thanks'],
  ]);

  ## make this wizard compatible with old URLs
  if ($object->param('se')) {
    $wizard->current_node($object, 'hv_single');
  }
  elsif ($object->param('ref')) {
    $wizard->current_node($object, 'hv_contact');
  }
  elsif ($object->param('kw') && !$object->param('results') ) {
    $wizard->current_node($object, 'hv_search');
  }

  $self->add_wizard($wizard);
  $self->wizard_panel('');
}

sub glossaryview {
  my $self = shift;
  my $object = $self->{object};

  $self->set_title('Ensembl Glossary');

  if( my $panel = $self->new_panel( 'Image',
    'code'    => "info$self->{flag}",
    'object'  => $self->{object},

  )) {
    $panel->add_components(qw(
      glossary          EnsEMBL::Web::Component::Help::glossary
    ));
    $self->add_panel( $panel );
  }
}

sub context_menu {
  my $self = shift;
  my $object = $self->{object};
  my $display_length = 34; #no of characters of the title that are to be displayed
  my $focus = $object->param('kw'); # get the current entry
  $focus =~ s/(.*)\#/$1/;

  my @result_array = @{ $object->Obj->{'index'} || [] };
  foreach my $row ( @result_array ) {
    (my $name = $row->{'title'} ) =~ s/^(.{50})...+/\1.../;
    #if ($name =~ /^Ensembl/) {
    #  $name =~ s/^Ensembl //;
    #}

    $self->add_block( lc($row->{'category'}), 'bulleted', $row->{'category'} );
    my %hash= ( 'text' => $name );
       $hash{ 'title' } =  $row->{'title'} unless $name eq $row->{'title'};
    if( $row->{'keyword'} eq $focus ) {
      $hash{ 'text'  } =  "$name";
    } else {
      $hash{ 'href'  } =  $object->_help_URL( {'kw'=>$row->{'keyword'}} );
    }
    $self->add_entry( lc($row->{'category'}), %hash );
  }
}

1;
