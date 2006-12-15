package EnsEMBL::Web::Document::WebPage;

use EnsEMBL::Web::Root;
use EnsEMBL::Web::Proxy::Factory;
use EnsEMBL::Web::Timer;
use Exporter;
use Apache2::Const qw(:common M_GET);
use EnsEMBL::Web::DBSQL::UserDB;
use EnsEMBL::Web::User;

use EnsEMBL::Web::RegObj;

use CGI qw(header escapeHTML unescape);
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
    'page'         => undef,
    'factory'      => undef,
    'access'       => undef,
    'timer'        => $ENSEMBL_WEB_REGISTRY->timer,
    'species_defs' => $ENSEMBL_WEB_REGISTRY->species_defs
  };
  bless $self, $class;
  my %parameters = @_;
  $| = 1;
## Input module...
  my $script = $parameters{'scriptname'} || $ENV{'ENSEMBL_SCRIPT'};
  my $input  = $parameters{'cgi'}        || new CGI;
  $ENSEMBL_WEB_REGISTRY->get_session->set_input( $input );
  $self->_prof("Parameters initialised from input");
## Access restriction parameters
  $self->{'access'} = $parameters{'access'};

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
  $self->page = new $doc_module( $rend, $self->{'timer'}, $self->{'species_defs'}, $self->{'access'} );          $self->_prof("Page object compiled and initialized");

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
#       $sc->update_from_input( $input, $rend->{'r'} ) if $sc;        $self->_prof("Script config updated from input");
  }
  return $self;
}

sub configure {
  my( $self, $object, @functions ) = @_;
  my $objecttype;
  if (ref($object)) { ## Actual object
    $objecttype = $object->__objecttype;
  }
  elsif ($object =~ /^\w+$/) { ## String (type of E::W object)
    $objecttype = $object;
  }
  else {
    $objecttype = 'Static';
  }
  $objecttype = 'DAS' if ($objecttype =~ /^DAS::.+/);

  my $flag = 0;
  my @T = ('EnsEMBL::Web', '', @{$ENSEMBL_PLUGINS});

  my $FUNCTIONS_CALLED = {};
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
	  # If this configuration module can perform this function do so...
          $self->{wizard} = $CONF->{wizard};
          eval { $CONF->$FN(); };
          if( $@ ) { # Catch any errors and display as a "configuration runtime error"
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
	  } else {
            $FUNCTIONS_CALLED->{$FN} = 1;
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
      );
    }
  }
  foreach my $FN ( @functions ) {
    unless( $FUNCTIONS_CALLED->{$FN} ) {
      if( $objecttype eq 'DAS' ) {
        $self->problem('Fatal', 'Bad request', 'Unimplemented');
      } else {
        warn "Can't do configuration function $FN on $objecttype objects";
      }
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
  my $user_id = $self->get_user_id;
  my $access = $self->{'access'};
  my $permitted;

  if ($access) {
  ## check script-wide access rules
    $permitted = $self->check_access($access);
  }
  else {
    $permitted = 1; ## default is to allow access, so ordinary pages don't break!
  }

  if ($permitted) {
    if ($self->{wizard}) {
      my $object = ${$self->dataObjects}[0];
      my $node = $self->{wizard}->current_node($object);
      $access = $self->{wizard}->node_access($node);
      if ($access) {
        $permitted = $self->check_access($access);
      }
      if ($permitted) {
        $self->_node_hop($node);
      }
    }
    else { ## not a wizard page after all!
      $self->render;
    }
  }

  if (!$permitted) {
    my $URL = '/common/access_denied';
    $self->redirect($URL);
  }
}

sub _node_hop {
  my ($self, $node, $loop) = @_;
  $loop++;
  warn "WIZARD NODE: " . $node;
  if ($loop > 10 || !$self->{wizard}->isa_node($node) || $self->{wizard}->isa_page($node)) {
    ## render page if not a processing node or doesn't exist
    $self->render;
  }
  else {
    ## do whatever processing is required by this node
    my $object = ${$self->dataObjects}[0];
    warn "OBJECT FOR WIZARD: " . $object->[0];
    my $return_value = $self->{wizard}->$node($object);

    my %parameter = %{$return_value} if (ref($return_value) =~ /HASH/);
    if (my $next_node = $parameter{'hop'}) {
      $self->_node_hop($next_node, $loop);
    }
    else {
      my $URL;
      if (my $exit = $parameter{'exit'}) {
        $URL = CGI::unescape($exit);
      }
      else { 
        $URL = '/'.$object->species.'/'.$object->script;
      }

      ## unpack returned parameters into a URL
      my $tally = 0;
      my $param_count = scalar(keys %parameter);
      if ($param_count && !$parameter{'exit'}) {
        $URL .= '?';
      }
      foreach my $param_name (keys %parameter) {
        warn "CHECKING for USER keys: " . $param_name;
        if ($param_name eq 'set_cookie') {
          if ($parameter{'set_cookie'}) {
            $self->login($parameter{'set_cookie'});
          }
          else {
            $self->logout;
          }
          next;
        }

        ## assemble rest of url for non-exit redirects
        if (!$parameter{'exit'}) {
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
      }
      my $r = $self->page->renderer->{'r'};

      ## do redirect
      $r->headers_out->add( "Location" => $URL ); 
      $r->err_headers_out->add( "Location" => $URL );
      $r->status( REDIRECT );
    }
  }
}

sub check_access {
  my ($self, $access) = @_;
  my $ok = 0;
  warn "CHECKING ACCESS";
  foreach my $key (keys %{ $access }) {
     warn "ACCESS KEY: " . $key;
  }
  if ($access->{'login'} && $self->get_user_id) {
    $ok = 1;
  }
  else {
    return unless $self->get_user_id;
    my $object = ${$self->dataObjects}[0];
    my $user;
    if ($object->__objecttype eq 'User') {
      $user = $object;
    } 
    else {
      #$user = EnsEMBL::Web::Object::User->new();
    }
    if ($access->{'group'}) {
      my $membership = $user->get_membership($object->user_id, $access->{'group'});
      my $member = $membership->[0];
      if ($member->{'member_status'} eq 'active') {
        if ($access->{'level'}) {
          warn 'Access ', $access->{'level'}, ', User ', $member->{'member_level'};
          $ok = 1 if $member->{'member_level'} eq $access->{'level'};
        }
        else {
          $ok = 1;
        }
      }
    }
    else {
      $ok = 1;
    }
  }

  return $ok;
}

sub logout {
  my $self = shift;

  ## setting a (blank) expired cookie deletes the current one
  my $cookie = CGI::Cookie->new(
      -name    => $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_USER_COOKIE,
      -value   => '',
      -domain  => $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_COOKIEHOST,
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
  warn "USER LOGIN: " . $user_id; 
  my $encrypted = EnsEMBL::Web::DBSQL::UserDB::encryptID($user_id);
  my $cookie = CGI::Cookie->new(
      -name    => $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_USER_COOKIE,
      -value   => $encrypted,
      -domain  => $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_COOKIEHOST,
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

sub DESTROY {
  Bio::EnsEMBL::Registry->disconnect_all();
}

sub simple { simple_webpage( @_ ); }
sub simple_webpage {
  my ($type, $access) = @_;
  my $self = __PACKAGE__->new( 'objecttype' => $type, {'access'=>$access} );
  if( $self->has_a_problem ) {
     $self->render_error_page;
  } else {
    foreach my $object( @{$self->dataObjects} ) {
      $self->configure( $object, $object->script, 'context_menu', 'context_location' );
    }
    $self->factory->fix_session;
=pod
    my $object = $self->dataObjects->[0];
    ## get access parameters
    while (my ($k, $v) = each (%$access)) {
      next if $v;
      if ($k eq 'user_id') {
        $access->{'user_id'} = $object->user_id;
      }
      else {
        $access->{$k} = $object->param($k);
      } 
    }
=cut
    $self->action($access);
  }
  #warn $self->timer->render();
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
    $self->factory->fix_session;
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
    $self->factory->fix_session;
     $self->action;
  }
  return 1;
}


1;
