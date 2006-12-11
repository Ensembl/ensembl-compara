package BioMart::Web::PageStub;
use EnsEMBL::Web::Apache::Handlers;
use EnsEMBL::Web::Document::Renderer::Apache;
use EnsEMBL::Web::Document::Dynamic;
use EnsEMBL::Web::Document::Static;

sub new {
  my( $class, $session ) = @_;
  my $renderer = new EnsEMBL::Web::Document::Renderer::Apache;
  my $page     = new EnsEMBL::Web::Document::Dynamic( $renderer,undef,$ENSEMBL_WEB_REGISTRY->species_defs );
  $page->_initialize_HTML;
  #$page->set_doc_type( 'HTML', '4.01 Trans' );
  $page->masthead->sp_bio    ||= 'BioMart';
  $page->masthead->sp_common ||= 'BioMart';
  $page->javascript->add_source( '/martview/js/martview.js'           );
  $page->javascript->add_script( 'addLoadEvent( setVisibleStatus )' );
  $page->stylesheet->add_sheet(  'all', '/martview/martview.css'      );

  my $self = { 'page' => $page, 'session' => $session };
  bless $self, $class;
  return $self;
}

sub start {
  my $self = shift;
  $self->{'page'}->render_start;
  print qq(
<div id="page"><div id="i1"><div id="i2"><div class="sptop">&nbsp;</div>
<div id="main_body_content" class="panel">);
}

sub end {
  my $self = shift;
  print qq(</div>
</div></div></div>);
  if($self->{'session'}->param('__validatorError')) {
  ( my $inc = $self->{'session'}->param("__validationError") ) =~ s/\n/\\n/;
  $inc =~s/\'/\\\'/;
  print qq(<script language="JavaScript" type="text/javascript">
        //<![CDATA[
        alert('$inc');
        //]]>
        </script>);
  }
  $self->{'page'}->render_end;
}

1;
