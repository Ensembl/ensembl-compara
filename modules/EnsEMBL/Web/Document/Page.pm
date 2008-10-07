package EnsEMBL::Web::Document::Page;

use strict;
use CGI qw(escapeHTML);
use Data::Dumper qw(Dumper);

use constant DEFAULT_DOCTYPE         => 'HTML';
use constant DEFAULT_DOCTYPE_VERSION => '4.01 Trans';
use constant DEFAULT_ENCODING        => 'ISO-8859-1';
use constant DEFAULT_LANGUAGE        => 'en-gb';

use EnsEMBL::Web::Root;
use EnsEMBL::Web::Tools::PluginLocator;
our @ISA = qw(EnsEMBL::Web::Root);

our %DOCUMENT_TYPES = (
  'none' => { 'none' => '' },
  'HTML' => {
    '2.0'         => '"-//IETF//DTD HTML 2.0 Level 2//EN"',
    '3.0'         => '"-//IETF//DTD HTML 3.0//EN"',
    '3.2'         => '"-//W3C//DTD HTML 3.2 Final//EN"',
    '4.01 Strict' => '"-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd"',
    '4.01 Trans'  => '"-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd"',
    '4.01 Frame'  => '"-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd"'
  },
  'XHTML' => {
    '1.0 Strict' => '"-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"',
    '1.0 Trans'  => '"-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"',
    '1.0 Frame'  => '"-//W3C//DTD XHTML 1.0 Frameset//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd"',
    '1.1'        => '"-//W3C//DTD XHTML 1.1//EN"'
  },
  'XML' => {
    'DASGFF' => '"http://www.biodas.org/dtd/dasgff.dtd"',
    'DASDSN' => '"http://www.biodas.org/dtd/dasdsn.dtd"',
    'DASEP'  => '"http://www.biodas.org/dtd/dasep.dtd"',
    'DASDNA' => '"http://www.biodas.org/dtd/dasdna.dtd"',
    'DASSEQUENCE' => '"http://www.biodas.org/dtd/dassequence.dtd"',
    'DASSTYLE' =>  '"http://www.biodas.org/dtd/dasstyle.dtd"',
    'DASTYPES' =>  '"http://www.biodas.org/dtd/dastypes.dtd"',
    'rss version="0.91"' => '"http://my.netscape.com/publish/formats/rss-0.91.dtd"',
    'rss version="2.0"'  => '"http://www.silmaril.ie/software/rss2.dtd"',
    'xhtml' => '"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"',
    },
);

sub plugin_locator {
  ### a
  my ($self, $locator) = @_;
  if ($locator) {
    $self->{'plugin_locator'} = $locator;
  }
  return $self->{'plugin_locator'};
}

sub call_child_functions {
  my $self = shift;
  if (!$self->plugin_locator->results) {
    $self->plugin_locator->include;
    $self->plugin_locator->create_all;
  }
  $self->plugin_locator->call(@_);
}

sub set_doc_type {
  my( $self, $type, $V ) = @_;
  return unless exists $DOCUMENT_TYPES{$type}{$V};
  $self->{'doc_type'} = $type;
  $self->{'doc_type_version'} = $V;
}

sub access_restrictions {
  my $self = shift;
  return $self->{'access'};
}

sub new {
  my( $class )     = shift;
  my $renderer     = shift;
  my $timer        = shift;
  my $species_defs = shift;
  my $input        = shift;
  my $self = {
    'body_attr'         => {},
    'species_defs'      => $species_defs,
    'input'             => $input,
    'doc_type'          => DEFAULT_DOCTYPE,
    'doc_type_version'  => DEFAULT_DOCTYPE_VERSION,
    'encoding'          => DEFAULT_ENCODING,
    'language'          => DEFAULT_LANGUAGE,
    'head_order'        => [],
    'body_order'        => [],
    '_renderer'         => $renderer,
    'timer'             => $timer,
    'plugin_locator'    => EnsEMBL::Web::Tools::PluginLocator->new( (
                                         locations  => [ 'EnsEMBL::Web', reverse @{ $species_defs->ENSEMBL_PLUGIN_ROOTS } ], 
                                         suffix     => "Document::Configure",
                                         method     => "new"
                                                                  ) )
  };
  bless $self, $class;
  $self->plugin_locator->parameters([ $self ]);
  return $self;
}


sub body_elements{
  my $self = shift;
  return map{$_->[0]} @{$self->{'body_order'}};
}

sub add_body_elements {
  my $self = shift;
  while( my @T = splice(@_,0,2) ) {
    push @{$self->{'body_order'}}, \@T;
  }
}

sub add_body_element{ 
  my $self = shift; 
  return $self->add_body_elements(@_);
}

sub add_body_element_first{
  my( $self, $code, $function ) = @_;
  my $elements = $self->{'body_order'};
  unshift( @{$elements}, [$code, $function] );
  return 1;
}

sub add_body_element_last{
  my( $self, $code, $function ) = @_;
  my $elements = $self->{'body_order'};
  unshift( @{$elements}, [$code, $function] );
  return 1;
}

sub add_body_element_before{
  my( $self, $oldcode, $code, $function ) = @_;
  my $elements = $self->{'body_order'};
  for( my $i=0; $i<@{$elements}; $i++ ){
    if( $elements->[$i]->[0] eq $oldcode ){
      splice( @{$elements},$i,0,[$code, $function] );
      last;
    }
  }
  return 1;
}

sub add_body_element_after{
  my( $self, $oldcode, $code, $function ) = @_;
  my $elements = $self->{'body_order'};
  for( my $i=0; $i<@{$elements}; $i++ ){
    if( $elements->[$i]->[0] eq $oldcode ){
      splice( @{$elements},$i+1,0,[$code, $function] );
      last;
    }
  }
  return 1;
}

sub remove_body_element{
  my( $self, $code ) = @_;
  my $elements = $self->{'body_order'};
  for( my $i=0; $i<@{$elements}; $i++ ){
    if( $elements->[$i]->[0] eq $code ){
      splice( @{$elements},$i,1 );
      last;
    }
  }
  return 1;
}

sub replace_body_element{
  my( $self, $code, $function ) = @_;
  my $elements = $self->{'body_order'};
  for( my $i=0; $i<@{$elements}; $i++ ){
    if( $elements->[$i]->[0] eq $code ){
      $elements->[$i]->[1] = $function;
      last;
    }
  }
  return 1;
}

sub head_elements{
  my $self = shift;
  return map{$_->[0]} @{$self->{'head_order'}};
}

sub add_head_elements {
  my $self = shift;
  while( my @T = splice(@_,0,2) ) {
    push @{$self->{'head_order'}}, \@T;
  }
}

sub add_head_element_first{
  my( $self, $code, $function ) = @_;
  my $elements = $self->{'head_order'};
  unshift( @{$elements}, [$code, $function] );
  return 1;
}

sub add_head_element_last{
  my( $self, $code, $function ) = @_;
  my $elements = $self->{'head_order'};
  unshift( @{$elements}, [$code, $function] );
  return 1;
}

sub add_head_element_before{
  my( $self, $oldcode, $code, $function ) = @_;
  my $elements = $self->{'head_order'};
  for( my $i=0; $i<@{$elements}; $i++ ){
    if( $elements->[$i]->[0] eq $oldcode ){
      splice( @{$elements},$i,0,[$code, $function] );
      last;
    }
    unshift( @{$elements}, [$code, $function] );
  }
  return 1;
}

sub add_head_element_after{
  my( $self, $oldcode, $code, $function ) = @_;
  my $elements = $self->{'head_order'};
  for( my $i=0; $i<@{$elements}; $i++ ){
    if( $elements->[$i]->[0] eq $oldcode ){
      splice( @{$elements},$i+1,0,[$code, $function] );
      last;
    }
    push( @{$elements}, [$code, $function] );
  }
  return 1;
}

sub remove_head_element{
  my( $self, $code ) = @_;
  my $elements = $self->{'head_order'};
  for( my $i=0; $i<@{$elements}; $i++ ){
    if( $elements->[$i]->[0] eq $code ){
      splice( @{$elements},$i,1 );
      last;
    }
  }
  return 1;
}

sub replace_head_element{
  my( $self, $code, $function ) = @_;
  my $elements = $self->{'head_order'};
  for( my $i=0; $i<@{$elements}; $i++ ){
    if( $elements->[$i]->[0] eq $code ){
      $elements->[$i] = [$code, $function];
      last;
    }
  }
  return 1;
}



sub species_defs { return $_[0]{'species_defs'}; }
sub head_order :lvalue { $_[0]{'head_order'} }
sub body_order :lvalue { $_[0]{'body_order'} }
sub doc_type {
  my $self = shift;
  $self->{'doc_type'} = DEFAULT_DOCTYPE
    unless exists $DOCUMENT_TYPES{$self->{'doc_type'}};
  $self->{'doc_type_version'} = DEFAULT_DOCTYPE_VERSION
    unless exists $DOCUMENT_TYPES{$self->{'doc_type'}}{$self->{'doc_type_version'}};
#  return "<!DOCTYPE html PUBLIC @{[$DOCUMENT_TYPES{$self->{'doc_type'}}{$self->{'doc_type_version'}} ]}>\n";

  return '' if $self->{'doc_type'} eq 'none';
  my $header = $self->{'doc_type'} eq 'XML' ? qq#<!DOCTYPE $self->{'doc_type_version'} SYSTEM @{[$DOCUMENT_TYPES{$self->{'doc_type'}}{$self->{'doc_type_version'}} ]}>\n# : "<!DOCTYPE html PUBLIC @{[$DOCUMENT_TYPES{$self->{'doc_type'}}{$self->{'doc_type_version'}} ]}>\n";

  return $header;
}

sub html_line {
  my $self = shift;
  return
    qq(<html @{[
      $self->{'doc_type'} eq 'XHTML' ?
      qq(xmlns="http://www.w3.org/1999/xhtml" xml:) :
      ''
    ]}lang="$self->{'language'}">\n);
}

sub _init( ) {
  my $self = shift;
  foreach my $entry ( @{$self->{'head_order'}}, @{$self->{'body_order'}} ) {
    my($O,$classname) = @$entry;
    next unless $self->dynamic_use( $classname ); 
    my $T;
    eval { $T = $classname->new( $self->{'timer'} ); $T->{_renderer} = $self->{_renderer}};
    if( $@ ) {
      warn $@;
      next;
    }
    $self->{$O} = $T;
    my $method_name = ref($self)."::$O";
    no strict 'refs'; 
    $self->timer_push( "$classname....." );
    *$method_name = sub :lvalue { $_[0]{$O} };
  }
}

sub clear_body_attr {
  my( $self, $K ) = @_;
  delete( $self->{'body_attr'}{$K} );
}

sub add_body_attr {
  my( $self, $K, $V ) = @_;
  $self->{'body_attr'}{lc($K)}.=$V;
}

sub printf { my $self = shift; $self->renderer->printf( @_ ) if $self->{'_renderer'}; }
sub print  { my $self = shift; $self->renderer->print( @_ )  if $self->{'_renderer'}; }

sub renderer :lvalue { $_[0]{'_renderer'} };

sub include_navigation {
  my $self = shift;
  $self->{_has_navigation} = shift if @_;
  return $self->{_has_navigation};
}

sub timer_push { $_[0]->{'timer'} && $_[0]->{'timer'}->push( $_[1], 1 ); }

sub render {
  my $self = shift;
  my $flag = shift;
  ## If this is an AJAX request then we will not render the page wrapper!
  if( $self->{'_modal_dialog_'} ) {
    ## We need to add the dialog tabs and navigation tree here....
    $self->global_context->render_modal;
    $self->local_context->render_modal;
    ## and then add in the fact that it is an XMLHttpRequest object to render the content only...
  }
  if ($self->renderer->r->headers_in->{'X-Requested-With'} eq 'XMLHttpRequest') {
    $self->content->render; 
    return;
  }
  ## This is now a full page...
  $self->_render_head_and_body_tag unless $flag eq 'end';
  #  my $X = $self->{'page_template'};
  my $X = '';
  if( $self->species_defs->ENSEMBL_DEBUG_FLAGS & 1024 && $flag ne 'end' ) {
    $X .= '  <div id="debug"></div>';  ## UNTIL WE GO LIVE PLEASE LEAVE THIS IN !
  }
  $X .= '
  <table class="mh" summary="layout table">
    <tr>
      <td id="mh_lo">[[logo]]</td>
      <td id="mh_search">[[search_box]]
      </td>
    </tr>
  </table>
  <table class="mh" summary="layout table">
    <tr>
      <td id="mh_bc">[[breadcrumbs]]</td>
      <td id="mh_lnk">[[tools]]
      </td>
    </tr>
  </table>
  <table class="mh" summary="layout table">
    <tr>
      <td>[[global_context]]</td>
    </tr>
  </table>
  <div style="position: relative">
  ' unless $flag eq 'end';
  if( $self->include_navigation ) {
    $X .= '
      <div id="nav">[[local_context]][[local_tools]]<p class="invisible">.</p></div>';
  }
  $X .= '
      <div id="main">
<!-- Start of real content --> ';

  $X .= '
      [[content]]' unless $flag;
  $X .= '
<!-- End of real content -->
      </div>' unless $flag eq 'start';
  unless ($flag eq 'start') {
    if( $self->include_navigation ) {
      $X .= '   <div id="footer">[[copyright]][[footerlinks]]</div>';
    }
    else {
      $X .= '   <div id="wide-footer">[[copyright]][[footerlinks]]</div>';
    }
  }
  $X .= '
  </div>
[[body_javascript]]';

  $self->timer_push( 'template generated' );
  while( $X =~ s/(.*?)\[\[([\w:]+)\]\]//sm ) {
    my($start,$page_element) = ($1,$2);
    $self->print( $start );
    eval{ $self->$page_element->render; };
    $self->printf( '%s - %s', $page_element, $@ ) if $@;
  }
  $self->print( $X );
  $self->_render_close_body_tag unless $flag eq 'start';
}

sub render_DAS {
  my( $self ) = shift;
  my $r = $self->renderer->{'r'};
  if( $r ) {
    $r->headers_out->add('X-Das-Status'  => '200'     );
    $r->headers_out->add('X-Das-Version' => 'DAS/1.5' );
  }
  $self->{'xsl'} = "/das/$self->{'subtype'}.xsl" if exists $self->{'subtype'}; #'/das/dasgff.xsl';
  $self->render_XML();
}
sub render_XML {
  my( $self ) = shift;

  $self->print(qq{<?xml version="1.0" standalone="no"?>\n});
  if( $self->{'xsl'} ){
    $self->print(qq(<?xml-stylesheet type="text/xsl" href="$self->{'xsl'}"?>\n));
  }
  $self->print( $self->doc_type);
  $self->print( "\<$self->{'doc_type_version'}\>\n" );

  foreach my $R ( @{$self->{'body_order'}} ) {
    my $attr = $R->[0];
    $self->$attr->render;
  }
  $self->print( "\<\/$self->{'doc_type_version'}\>\n" );

}

sub render_Excel {
  my $self = shift;

## Switch in the Excel file renderer
## requires the filehandle from the current renderer (works with Renderer::Apache and Renderer::File)
  my $renderer =  new EnsEMBL::Web::Document::Renderer::Excel({ 'fh' => $self->renderer->fh });
  foreach my $R ( @{$self->{'body_order'}} ) {
    my $attr = $R->[0];
    $self->$attr->{_renderer} = $renderer;
    $self->$attr->render;
  }
  $renderer->close;
}

sub render_Text {
  my $self = shift;
  foreach my $R ( @{$self->{'body_order'}} ) {
    my $attr = $R->[0];
    $self->$attr->render;
  }
}

sub render_TextGz {
  my $self = shift;
  my $renderer =  new EnsEMBL::Web::Document::Renderer::GzFile( );
  foreach my $R ( @{$self->{'body_order'}} ) {
    my $attr = $R->[0];
    $self->$attr->{_renderer} = $renderer;
    $self->$attr->render;
  }
  $renderer->close;
  $self->renderer->print( $renderer->raw_content );
  unlink $renderer->{'filename'};
}

sub render_start {
  my( $self ) = shift;
  $self->render( 'start' );
}

sub render_end {
  my( $self ) = shift;
  $self->render( 'end' );
}

sub _render_head_and_body_tag {
  my( $self ) = shift;
  if( $self->{doc_type} eq 'XHTML' ) {
    $self->print( qq(<?xml version="1.0" encoding="utf-8"?>\n) );
  }
  $self->print( $self->doc_type,$self->html_line,"<head>\n" );
  foreach my $R ( @{$self->{'head_order'}} ) {
    my $attr = $R->[0];
    $self->$attr->render;
    $self->timer_push( "Rendered $attr" );
  }
  $self->print( "</head>\n<body" );
  foreach my $K ( keys( %{$self->{'body_attr'}}) ) {
    next unless $self->{'body_attr'}{$K};
    $self->printf( ' %s="%s"', $K , CGI::escapeHTML( $self->{'body_attr'}{$K} ) );
  }
  $self->print( '>' );
}

sub _render_close_body_tag {
  $_[0]->print( "\n</body>\n</html>" );
}

1;
