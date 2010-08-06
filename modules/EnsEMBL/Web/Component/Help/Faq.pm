package EnsEMBL::Web::Component::Help::Faq;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::DBSQL::WebsiteAdaptor;

use base qw(EnsEMBL::Web::Component::Help);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $hub = $self->hub;
  my $id = $hub->param('id') || $hub->param('feedback');
  $id+=0;
  my $html = qq(<h2>FAQs</h2>);
  
  my $adaptor = EnsEMBL::Web::DBSQL::WebsiteAdaptor->new($hub);
  my $args;

  if ($id) {
    $args->{'id'} = $id;
  }
  elsif ($hub->param('kw')) {
    $args->{'kw'} = $hub->param('kw');
  }
  my @faqs = @{$adaptor->fetch_faqs($args)};  

  if (scalar(@faqs) > 0) {
  
    my $style = 'text-align:right;margin-right:2em';

    foreach my $faq (@faqs) {
      next unless $faq;

      $html .= sprintf(qq(<h3 id="faq%s">%s</h3>\n<p>%s</p>), $faq->{'id'}, $faq->{'question'}, $faq->{'answer'});
      if ($hub->param('feedback') && $hub->param('feedback') == $faq->{'id'}) {
        $html .= qq(<div style="$style">Thank you for your feedback</div>);
      } else {
        $html .= $self->help_feedback($style, $faq->{'id'}, return_url => '/Help/Faq', type => 'Faq');
      }

    }

    if (scalar(@faqs) == 1) {
      $html .= qq(<p><a href="/Help/Faq" class="popup">More FAQs</a></p>);
    }
  }

  $html .= qq(<hr /><p style="margin-top:1em">If you have any other questions about Ensembl, please do not hesitate to 
<a href="/Help/Contact" class="popup">contact our HelpDesk</a>. You may also like to subscribe to the 
<a href="http://www.ensembl.org/info/about/contact/mailing.html" class="cp-external">developers' mailing list</a>.</p>);

  return $html;
}

1;
