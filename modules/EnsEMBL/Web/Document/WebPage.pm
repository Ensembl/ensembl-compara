package EnsEMBL::Web::Document::WebPage;

use EnsEMBL::Web::Root;
use EnsEMBL::Web::Proxy::Factory;
use EnsEMBL::Web::Timer;
use EnsEMBL::Web::SpeciesDefs;
use Exporter;
use Apache::Constants qw(:common :response M_GET);

our $SD = EnsEMBL::Web::SpeciesDefs->new();

use CGI qw(header escapeHTML);
use CGI::Cookie;
use SiteDefs;
use strict;

use constant 'DEFAULT_RENDERER'   => 'Apache';
use constant 'DEFAULT_OUTPUTTYPE' => 'HTML';
use constant 'DEFAULT_DOCUMENT'   => 'Dynamic';

use Bio::EnsEMBL::Registry; # Required so we can do the disconnect all call!!
our @ISA = qw(EnsEMBL::Web::Root Exporter);
our @EXPORT_OK = qw(simple_webpage simple_with_redirect);
our @EXPORT    = @EXPORT_OK;

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
  my $input = $parameters{'cgi'} || new CGI;
  $self->_prof("Parameters initialised from input");
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
  $self->{'format'} = $input->param('_format') || $parameters{'outputtype'} || DEFAULT_OUTPUTTYPE;
  my $method = "_initialize_".($self->{'format'});

  $self->page->$method();
  $self->_prof("Output method initialized" );

## Finally we get to the Factory module!
  $self->factory = EnsEMBL::Web::Proxy::Factory->new(
    $parameters{'objecttype'}, { '_input' => $input, '_apache_handle' => $rend->{'r'} }
  );
  $self->factory->__data->{'timer'} = $self->{'timer'};
  $self->_prof("Factory compiled and objects created...");

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

  $objecttype = 'DAS' if ($objecttype =~ /^DAS::.+/);

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
          $self->{wizard} = $CONF->{wizard};
          eval { $CONF->$FN(); };
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
        else {

	    if ($objecttype eq 'DAS') {
		
		$self->problem('Fatal', 'Bad request', 'Unimplemented');


	    } else {

		warn "Can't do menu function $FN";
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

sub factory   :lvalue { $_[0]->{'factory'}; }
sub page      :lvalue { $_[0]->{'page'};    }

## Wrapper functions around factory and page....
sub has_fatal_problem { my $self = shift; return $self->factory->has_fatal_problem;       }
sub has_a_problem     { my $self = shift; return $self->factory->has_a_problem(@_);       }
sub has_problem_type  { my $self = shift; return $self->factory->has_problem_type( @_ );  }
sub problem           { my $self = shift; return $self->factory->problem(@_);             }
sub dataObjects       { my $self = shift; return $self->factory->DataObjects;             }

sub restrict  { 
  my $self = shift;
  $self->{'restrict'} = shift if @_;
  return $self->{'restrict'}; ## returns string   
}
sub groups  { 
  my $self = shift;
  $self->{'groups'} = shift if @_;
  return $self->{'groups'} || []; ## returns array ref    
}

sub get_user_id {
  my $self = shift;

  ## do we have one in the current session?
  my $user_id = $ENV{'ENSEMBL_USER_ID'};

  return $user_id;
}


## wrapper around redirect and render
sub action {
  my $self = shift;
  my $permitted = 1; ## default is to allow access, so ordinary pages don't break!
  my $user_id = $self->get_user_id;

=pod
  if ($self->restrict) { ## check for script-level access restrictions
    my $id = $self->get_user_id;

    my $groups = $self->groups;

    warn "RESTRICTED ACCESS! Permitted group(s): @$groups";
    $permitted = 0;
  }
=cut

  if ($permitted) {
    if ($self->{wizard}) {
      my $object = ${$self->dataObjects}[0];
      my $node = $self->{wizard}->current_node($object);
      $self->_node_hop($node);
    }
    else { ## not a wizard page after all!
      $self->render;
    }
  }
  else {
    my $URL = '/common/access_denied';
    $self->redirect($URL);
  }
}

sub _node_hop {
  my ($self, $node, $loop) = @_;
  $loop++;

  if ($loop > 10 || !$self->{wizard}->isa_node($node) || $self->{wizard}->isa_page($node)) {
    ## render page if not a processing node or function has recursed too many times!
    $self->render;
  }
  else {
    ## do whatever processing is required by this node
    my $object = ${$self->dataObjects}[0];
    my %parameter = %{$self->{wizard}->$node($object)};
    if (my $next_node = $parameter{'hop'}) {
      $self->_node_hop($next_node, $loop);
    }
    else {
      my $URL = '/'.$object->species.'/';
      if (my $exit = $parameter{'exit'}) {
        $URL .= $exit;
        delete($parameter{'exit'}); ## don't need to pass this parameter along
      }
      else { 
        $URL .= $object->script;
      }

      ## unpack returned parameters into a URL
      my $tally = 0;
      my $param_count = scalar(keys %parameter);
      $URL .= '?' if $param_count;
      foreach my $param_name (keys %parameter) {
        if ($param_name eq 'set_cookie') {
          $self->login($parameter{$param_name});
          next;
        }
        if (ref($parameter{$param_name}) eq 'ARRAY') {
          foreach my $param_value (@{$parameter{$param_name}}) {
            $URL .= ';' if $tally > 0;
            $URL .= $param_name.'='.$param_value;    
          }
        }
        else {
          $URL .= ';' if $tally > 0;
          $URL .= $param_name.'='.$parameter{$param_name};    
        }
        $tally++;
      }
      my $r = $self->page->renderer->{'r'};

      ## do redirect
      $r->headers_out->add( "Location" => $URL ); 
      $r->err_headers_out->add( "Location" => $URL );
      $r->status( REDIRECT );
    }
  }
}

sub logout {
  my $self = shift;

  ## setting a (blank) expired cookie deletes the current one
  my $cookie = CGI::Cookie->new(
      -name    => EnsEMBL::Web::SpeciesDefs->ENSEMBL_USER_COOKIE,
      -value   => '',
      -domain  => EnsEMBL::Web::SpeciesDefs->ENSEMBL_COOKIEHOST,
      -path    => "/",
      -expires => "Monday, 31-Dec-2000 23:59:59 GMT"
  );
  
  my $r = $self->page->renderer->{'r'};
  $r->headers_out->add( 'Set-cookie' => $cookie );
  $r->err_headers_out->add( 'Set-cookie' => $cookie );
  $r->subprocess_env->{'ENSEMBL_USER_ID'} = '';
  return 1;
}

sub login {
  my ($self, $user_id) = @_;
  
  my $encrypted = EnsEMBL::Web::DBSQL::UserDB::encryptID($user_id);
  my $cookie = CGI::Cookie->new(
      -name    => EnsEMBL::Web::SpeciesDefs->ENSEMBL_USER_COOKIE,
      -value   => $encrypted,
      -domain  => EnsEMBL::Web::SpeciesDefs->ENSEMBL_COOKIEHOST,
      -path    => "/",
      -expires => "Monday, 31-Dec-2010 23:59:59 GMT"
  );
  
  my $r = $self->page->renderer->{'r'};
  $r->headers_out->add( 'Set-cookie' => $cookie );
  $r->err_headers_out->add( 'Set-cookie' => $cookie );
  return 1;
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
  } elsif( $self->{'format'} eq 'XML' ) { 
    CGI::header("text/xml"); $self->page->render_XML;
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

  if (@problems) {
      $self->{'format'} = 'HTML';
      $self->page->set_doc_type('HTML', '4.01 Trans');
  }

  foreach my $problem ( sort { $b->isFatal <=> $a->isFatal } @problems ) {
    next if !$problem->isFatal && $self->{'show_fatal_only'};
    my $desc = $problem->description;
    $desc = "<p>$desc</p>" unless $desc =~ /<p/;

    # Find an example for the page
    my @eg;
    my $view = uc ($ENV{'ENSEMBL_SCRIPT'});
    my $ini_examples = $self->{'species_defs'}->SEARCH_LINKS;

    foreach ( map { $_ =~/^$view(\d)_TEXT/ ? [$1, $_] : () } keys %$ini_examples ) {
      my $url = $ini_examples->{$view."$_->[0]_URL"};
      push @eg, qq( <a href="$url">).$ini_examples->{$_->[1]}."</a>";
    }

    my $eg_html = join ", ", @eg;
    $eg_html = "<p>Try an example: $eg_html or use the search box.</p>" if $eg_html;

    $self->page->content->add_panel(
      new EnsEMBL::Web::Document::Panel(
        'caption' => $problem->name,
        'content' => qq(
  $desc
  $eg_html
  <p>
    If you think this is an error, or you have any questions, you can contact our HelpDesk team by clicking <strong><a href="javascript:void(window.open('/perl/helpview','helpview','width=700,height=550,resizable,scrollbars'))" class="red-button">here</a></strong>.
  </p>) 
      )
    );
    $self->factory->clear_problems();
  }
}

sub DESTROY { Bio::EnsEMBL::Registry->disconnect_all(); }

sub simple { simple_webpage( @_ ); }
sub simple_webpage {
  my $self = __PACKAGE__->new( 'objecttype' => shift );
  if( $self->has_a_problem ) {
     $self->render_error_page;
  } else {
    foreach my $object( @{$self->dataObjects} ) {
      $self->configure( $object, $object->script, 'context_menu', 'context_location' );
    }
    $self->action;
  }
  warn $self->timer->render();
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
    $self->action;
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
    } elsif ($self->has_problem_type('unmapped')) {
      my $f     = $self->factory;
      my $id  = $f->param('peptide') || $f->param('transcript') || $f->param('gene');
      my $type = $f->param('gene') ? 'Gene' : 'DnaAlignFeature';
      $self->redirect( sprintf "/%s/featureview?type=%s;id=%s",
        $self->factory->species, $type, $id 
      );
    } elsif ($self->has_problem_type('archived') ) {
      my $f     = $self->factory;
      my $id =  $f->param('peptide') || $f->param('transcript') || $f->param('gene');
      my $type;
      if ($f->param('peptide')) { $type = 'peptide'; }
      elsif ($f->param('transcript') ) { $type = 'transcript' }
      else { $type = "gene" ; }

      $self->redirect( sprintf "/%s/idhistoryview?%s=%s",
		       $self->factory->species, $type, $id 
		     );
    } else {
      $self->render_error_page;
    }
  } else {
     foreach my $object( @{$self->dataObjects} ) {
       $self->configure( $object, $object->script, 'context_menu', 'context_location' );
     }
     $self->action;
  }
  return 1;
}


1;
