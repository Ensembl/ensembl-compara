package EnsEMBL::Web::Document::Page;

use strict;
use CGI qw(escapeHTML);
use Data::Dumper qw(Dumper);

use constant DEFAULT_DOCTYPE         => 'HTML';
use constant DEFAULT_DOCTYPE_VERSION => '4.01 Trans';
use constant DEFAULT_ENCODING        => 'ISO-8859-1';
use constant DEFAULT_LANGUAGE        => 'en-gb';

use EnsEMBL::Web::Root;
our @ISA = qw(EnsEMBL::Web::Root);

our %DOCUMENT_TYPES = (
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
    'DASSTYLE' =>  '"http://www.biodas.org/dtd/dasstyle.dtd"',
    },
);

sub child_objects {
  my $self = shift;
  unless( $self->{'children'} ) {
    $self->{'children'} = [];
    foreach my $root( 'EnsEMBL::Web', reverse @{$self->species_defs->ENSEMBL_PLUGIN_ROOTS} ) {
      my $class_name = $root. '::Document::Configure';
      if( $self->dynamic_use( $class_name ) ) {
        push @{$self->{'children'}}, new $class_name;
      } else {
        (my $CS = $class_name ) =~ s/::/\\\//g;
        my $error = $self->dynamic_use_failure( $class_name );
        my $message = "^Can't locate $CS.pm in ";
        warn "MENU ERROR: Can't compile $class_name due to $error" unless $error =~ /$message/;
      }
    }
  }
  return @{$self->{'children'}};
}

sub call_child_functions {
  my( $self, @fns ) = @_;
  return unless @fns;
  foreach my $child ( $self->child_objects ) {
    foreach my $fn ( @fns ) {
      $child->$fn( $self ) if $child->can( $fn );
    }
  }
}

sub set_doc_type {
  my( $self, $type, $V ) = @_;
  return unless exists $DOCUMENT_TYPES{$type}{$V};
  $self->{'doc_type'} = $type;
  $self->{'doc_type_version'} = $V;
}

sub new {
  my( $class )     = shift;
  my $renderer     = shift;
  my $timer        = shift;
  my $species_defs = shift;
  my $self = {
    'body_attr'         => {},
    'species_defs'      => $species_defs,
    'doc_type'          => DEFAULT_DOCTYPE,
    'doc_type_version'  => DEFAULT_DOCTYPE_VERSION,
    'encoding'          => DEFAULT_ENCODING,
    'language'          => DEFAULT_LANGUAGE,
    'head_order'        => [],
    'body_order'        => [],
    '_renderer'         => $renderer,
    'timer'             => $timer
  };
  bless $self, $class;
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
    unshift( @{$elements}, [$code, $function] );
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
    push( @{$elements}, [$code, $function] );
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
      $elements->[$i] = [$code, $function];
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

  my $header = $self->{'doc_type'} eq 'XML' ? qq#<!DOCTYPE $self->{'doc_type_version'} SYSTEM @{[$DOCUMENT_TYPES{$self->{'doc_type'}}{$self->{'doc_type_version'}} ]}>\n# : "<!DOCTYPE html PUBLIC @{[$DOCUMENT_TYPES{$self->{'doc_type'}}{$self->{'doc_type_version'}} ]}>\n";

  return $header;
}

sub html_line {
  my $self = shift;
  return
    qq(<html@{[
      $self->{'doc_type'} eq 'XHTML' ?
      qq( xmlns="http://www.w3.org/1999/xhtml" xml:lang="$self->{'language'}" ) :
      ''
    ]} lang="$self->{'language'}">\n);
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

sub _prof { $_[0]->{'timer'} && $_[0]->{'timer'}->push( $_[1], 1 ); }
sub render {
  my( $self ) = shift;
  $self->_render_head_and_body_tag;
  foreach my $R ( @{$self->{'body_order'}} ) {
    my $attr = $R->[0];
    $self->$attr->render;
    $self->_prof( "Rendered $attr" );
  }
  $self->_render_close_body_tag;
}

sub render_XML {
  my( $self ) = shift;

  $self->print(qq{<?xml version="1.0" standalone="no"?>\n});
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
  foreach my $R ( @{$self->{'body_order'}} ) {
    my $attr = $R->[0];
    $self->$attr->render;
  }
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
  $self->_render_head_and_body_tag;
  foreach my $R ( @{$self->{'body_order'}} ) {
    my $attr = $R->[0];
    return if $attr eq 'content';
    $self->$attr->render;
  }
}

sub render_end {
  my( $self ) = shift;
  my $flag = 0;
  foreach my $R ( @{$self->{'body_order'}} ) {
    my $attr = $R->[0];
    $self->$attr->render if( $flag );
    $flag = 1 if $attr eq 'content';
  }
  $self->_render_close_body_tag;
}

sub _render_head_and_body_tag {
  my( $self ) = shift;
  $self->print( $self->doc_type,$self->html_line,"<head>\n" );
  foreach my $R ( @{$self->{'head_order'}} ) {
    my $attr = $R->[0];
    $self->$attr->render;
    $self->_prof( "Rendered $attr" );
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
