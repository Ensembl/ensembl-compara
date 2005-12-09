package EnsEMBL::Web::Document::WebPage;

use EnsEMBL::Web::Root;
use EnsEMBL::Web::Proxy::Factory;
use EnsEMBL::Web::Timer;
use EnsEMBL::Web::SpeciesDefs;
use Apache::Constants qw(:common :response);

our $SD = EnsEMBL::Web::SpeciesDefs->new();

use CGI qw(header escapeHTML);
use SiteDefs;
use strict;

use constant 'DEFAULT_RENDERER'   => 'Apache';
use constant 'DEFAULT_OUTPUTTYPE' => 'HTML';
use constant 'DEFAULT_DOCUMENT'   => 'Dynamic';

use Bio::EnsEMBL::Registry; # Required so we can do the disconnect all call!!
our @ISA = qw(EnsEMBL::Web::Root);

sub _prof { my $self = shift; $self->timer->push( @_ ); }
sub timer { return $_[0]{'timer'}; }

sub new {
  my $class = shift;
  my $self = {
    'page'    => undef,
    'factory' => undef,
    'timer'   => new EnsEMBL::Web::Timer(),
    'species_defs' => $SD
  };
  bless $self, $class;
  my %parameters = @_;
  $| = 1;
## Input module...
  my $script = $parameters{'scriptname'} || $ENV{'ENSEMBL_SCRIPT'};
  my $input = new CGI;                                               $self->_prof("Parameters initialised from input");
## Page module...

## Compile and create renderer ... [ Apache, File, ... ]
  my $renderer_type = $parameters{'renderer'} || DEFAULT_RENDERER;
  my $render_module = "EnsEMBL::Web::Document::Renderer::$parameters{'renderer'}";
  unless( $self->dynamic_use( $render_module ) ) { ## If fails to compile try default rendered
    $render_module = "EnsEMBL::Web::Document::Renderer::".DEFAULT_RENDERER;
    $self->dynamic_use( $render_module ); 
  }
  my $rend = new $render_module();                                   $self->_prof("Renderer compiled and initialized");

## Compile and create "Document" object ... [ Dynamic, Popup, ... ]
  my $doctype = $parameters{'doctype'} || DEFAULT_DOCUMENT;
  my $doc_module = "EnsEMBL::Web::Document::$doctype";
  unless( $self->dynamic_use( $doc_module ) ) {
    $doc_module = "EnsEMBL::Web::Document::".DEFAULT_DOCUMENT;
    $self->dynamic_use( $doc_module ); 
  }
  $self->page = new $doc_module( $rend, $self->{'timer'}, $self->{'species_defs'} );          $self->_prof("Page object compiled and initialized");

## Initialize output type! [ HTML, XML, Excel, Txt ]
  $self->{'format'} = $input->param('_format') || DEFAULT_OUTPUTTYPE;
  my $method = "_initialize_".($self->{'format'});
  $self->page->$method();                                            $self->_prof("Output method initialized" );

## Finally we get to the Factory module!
  $self->factory = EnsEMBL::Web::Proxy::Factory->new(
    $parameters{'objecttype'}, { '_input' => $input, '_apache_handle' => $rend->{'r'} }
  );                                                                 $self->_prof("Factory compiled");
  return $self if $self->factory->has_fatal_problem();
  eval { $self->factory->createObjects(); };
  if( $@ ) {
    $self->problem( 'fatal', "Unable to execute createObject on Factory of type $parameters{'objecttype'}.", $@ );
                                                                     $self->_prof("Object creation failed");
  } else {
                                                                     $self->_prof("Objects created");
    my $sc = $self->factory->get_scriptconfig( );
       $sc->update_from_input( $input, $rend->{'r'} ) if $sc;        $self->_prof("Script config updated from input");
  }
  return $self;
}

sub configure {
  my( $self, $object, @functions ) = @_;
  my $objecttype = $object ? $object->__objecttype : 'Static';
  my $flag = 0;
  my @T = ('EnsEMBL::Web', '', @{$ENSEMBL_PLUGINS});
  while( my ($module_root, $X) = splice( @T, 0, 2) ) {
                           # Starting with the standard EnsEMBL module configure
                           # the script....
                           # Then loop through the plugins in order after that...
                           # First work out what the module name is - to see if it
                           # can be "used"
    $flag ++;
    my $config_module_name = $module_root."::Configuration::$objecttype";
    if( $self->dynamic_use( $config_module_name ) ) { ## Successfully used
                           # If it has been successfully used then look for
                           # the functions named in the script "configure" line
                           # of the script.
      my $CONF = $config_module_name->new( $self->page, $object, $flag );
      foreach my $FN ( @functions ) { 
        if( $CONF->can($FN) ) {
                           # If this configuration module can perform this
                           # function do so...
          eval { $CONF->$FN(); };
          $self->{wizard} = $CONF->{wizard};
          if( $@ ) { 
                           # Catch any errors and display as a "configuration runtime error"
            $self->page->content->add_panel( 
              new EnsEMBL::Web::Document::Panel(
               'caption' => 'Configuration module runtime error',
               'content' => sprintf( qq(
    <p>
      Unable to execute configuration $FN from configuration module <b>$config_module_name</b>
      due to the following error:
    </p>
    <pre>%s</pre>), $self->_format_error($@) )
              )
            );
          }
        }
      }
    } elsif( $self->dynamic_use_failure( $config_module_name ) !~ /^Can't locate/ ) { 
                           # Handle "use" failures gracefully... 
                           # Firstly skip Can't locate errors
                           # o/w display a "compile time" error message.
      $self->page->content->add_panel(
        new EnsEMBL::Web::Document::Panel(
         'caption' => 'Configuration module compilation error',
         'content' => sprintf( qq(
    <p>
      Unable to use Configuration module <b>$config_module_name</b> due to 
      the following error:
    </p>
    <pre>%s</pre>), $self->_format_error( $self->dynamic_use_failure( $config_module_name )) )
        )
      )
    }
  }
  $self->add_error_panels(); # Add error panels to end of display!!
  $self->_prof("Script configured ($objecttype)");
}   

sub static_links {
  my $self = shift;
#  $self->configure( undef, 'links' );
#  $self->_prof("Static links added");
}

sub factory :lvalue { $_[0]->{'factory'}; }
sub page    :lvalue { $_[0]->{'page'};    }

## Wrapper functions around factory and page....
sub has_fatal_problem { my $self = shift; return $self->factory->has_fatal_problem;       }
sub has_a_problem     { my $self = shift; return $self->factory->has_a_problem(@_);       }
sub has_problem_type  { my $self = shift; return $self->factory->has_problem_type( @_ );  }
sub problem           { my $self = shift; return $self->factory->problem(@_);             }
sub dataObjects       { my $self = shift; return $self->factory->DataObjects;             }

## wrapper around redirect and render, so wizard can choose
sub action {
  my $self = shift;

  if ($self->{wizard}) {
    my $object = ${$self->dataObjects}[0];
    my $node = $self->{wizard}->current_node($object);
    if (!$self->{wizard}->isa_page($node)) { ## isn't a web page
      ## do whatever processing is required by this node
      my %parameter = %{$self->{wizard}->$node($object)};
      ## unpack returned parameters into a URL
      my $URL = '/'.$object->species.'/'.$object->script.'?';
      my $count = 0;
      foreach my $param (keys %parameter) {
        $URL .= ';' if $count > 0;
        $URL .= $param.'='.$parameter{$param};    
        $count++;
      }
      warn "Redirecting to $URL";
      $URL = "http://ensarc-1-14.internal.sanger.ac.uk:10000$URL";
      my $r = $self->page->renderer->{'r'};
      $r->headers_out->add( "Location" => $URL );
      $r->err_headers_out->add( "Location" => $URL );
      $r->status( REDIRECT );
    }
    else {
      warn "Rendering page $node";
      $self->render;
    }
  }
  else { ## not a wizard page after all!
    warn "Rendering non-wizard page";
    $self->render;
  }
}

sub redirect {
  my( $self, $URL ) = @_;
  CGI::redirect( $URL );
  alarm(0);
}

sub render {
  my $self = shift;
  if( $self->{'format'} eq 'Text' ) { 
    CGI::header("text/plain"); $self->page->render_Text;
  } elsif( $self->{'format'} eq 'Excel' ) { 
    CGI::header(
      -type => "application/x-msexcel",
      -attachment => "ensembl.xls"
    );
    $self->page->render_Excel;
  } elsif( $self->{'format'} eq 'TextGz' ) { 
    CGI::header(
      -type => "application/octet-stream",
      -attachment => "ensembl.txt.gz"
    );
    $self->page->render_TextGz;
  } else {
    CGI::header; $self->static_links; $self->page->render;
  }
}

sub render_popup {
  my $self = shift;
  if( $self->{'format'} eq 'Text' ) { 
    CGI::header("text/plain");
    $self->page->render_Text;
  } else { 
    CGI::header;
    $self->page->render;
  }
}

sub render_error_page { 
  my $self = shift;
  $self->add_error_panels( @_ );
  $self->render();
}

sub add_error_panels {
  my( $self, @problems ) = @_;
  @problems = @{$self->problem} if !@problems && $self->factory;
  foreach my $problem ( sort { $b->isFatal <=> $a->isFatal } @problems ) {
    next if !$problem->isFatal && $self->{'show_fatal_only'};
    my $desc = $problem->description;
    $desc = "<p>$desc</p>" unless $desc =~ /<p/;
    $self->page->content->add_panel(
      new EnsEMBL::Web::Document::Panel(
        'caption' => $problem->name,
        'content' => qq(
  $desc
  <p>
    Please contact our HelpDesk team, by clicking on the HELP link in the
    top right hand of this page if you think this is an error or have any questions.
  </p>) 
      )
    );
    $self->factory->clear_problems();
  }
}

sub DESTROY { Bio::EnsEMBL::Registry->disconnect_all(); }

sub simple {
  my $self = __PACKAGE__->new( 'objecttype' => shift );
  if( $self->has_a_problem ) {
     $self->render_error_page;
  } else {
     foreach my $object( @{$self->dataObjects} ) {
       $self->configure( $object, $object->script, 'context_menu', 'context_location' );
     }
     $self->render;
  }
}

sub wrapper {
  my $objecttype = shift;
  my %params = @_;
  my %new_params = ('objecttype' => $objecttype );
  foreach(qw(renderer outputtype scriptname doctype)) {
    $new_params{$_} = $params{$_} if $params{$_};
  }
  my $self = __PACKAGE__->new( %new_params );
  if( $self->has_a_problem ) {
    $self->render_error_page;
  } else {
    foreach my $object( @{$self->dataObjects} ) {
      $self->configure( $object, $object->script, @{$params{'extra_config'}||[]} );
    }
    $self->render;
  }
}

sub simple_with_redirect {
  my $self = __PACKAGE__->new( 'objecttype' => shift );
  if( $self->has_a_problem ) {
    if( $self->has_problem_type('mapped_id') ) {
      my $feature = $self->factory->__data->{'objects'}[0];
      $self->redirect( sprintf "/%s/%s?%s",
        $self->factory->species, $self->factory->script,
        join(';',map {"$_=$feature->{$_}"} keys %$feature )
      );
    } else {
      $self->render_error_page;
    }
  } else {
     foreach my $object( @{$self->dataObjects} ) {
       $self->configure( $object, $object->script, 'context_menu', 'context_location' );
     }
     $self->render;
  }
}


1;
