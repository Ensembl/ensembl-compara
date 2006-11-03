package EnsEMBL::Web::Document::DataView;

use EnsEMBL::Web::Document::WebPage;
use EnsEMBL::Web::DBSQL::ViewAdaptor;
use CGI;
our @ISA = qw(EnsEMBL::Web::Document::WebPage);

{


sub simple {
  my ($type, $definition) = @_;
  my $self = __PACKAGE__->new(('objecttype' => $type, 'doctype' => 'View'));
  my $cgi = CGI->new; 

  if ($cgi->param) {
    my $action = "dataview_" . $definition->action;
    $self->redirect($definition->on_complete);
  } else {
    CGI::header;
    $self->page->render($definition);
  } 

}

sub dataview_create {
  my $self = shift;
  my $adaptor = EnsEMBL::Web::DBSQL::ViewAdaptor->new;
}


}

1;
