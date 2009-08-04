package EnsEMBL::Web::Component::Help::Faq;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Help);
use CGI qw(escapeHTML);
use EnsEMBL::Web::Data::Faq;
use Apache2::RequestUtil;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $id = $object->param('id') || $object->param('feedback');
  $id+=0;
  my $html = qq(<h2>FAQs</h2>);
  
  my @faqs;
  if ($id) {
    @faqs = (EnsEMBL::Web::Data::Faq->find('help_record_id' => $id, 'status' => 'live'));
  }
  elsif (my $kw = $object->param('kw')) {
    @faqs = EnsEMBL::Web::Data::Faq->find('keyword' => $kw, 'status' => 'live');
  }
  else {
    @faqs = EnsEMBL::Web::Data::Faq->fetch_sorted;
  }

  my $r = Apache2::RequestUtil->request();
  if (scalar(@faqs) > 0) {
  
    my $style = 'text-align:right;margin-right:2em';

    foreach my $faq (@faqs) {

      $html .= sprintf(qq(<h3 id="faq%s">%s</h3>\n<p>%s</p>), $faq->help_record_id, $faq->question, $faq->answer);
      if ($object->param('feedback') && $object->param('feedback') == $faq->help_record_id) {
        $html .= qq(<div style="$style">Thank you for your feedback</div>);
      } else {
        $html .= $self->help_feedback(
          $style, $faq->help_record_id, return_url => '/Help/Faq', type => 'Faq', 
          '_referer' => $object->param('_referer'),
          'x_requested_with' => $object->param('x_requested_with')||$r->headers_in->{'X-Requested-With'}
        );
      }

    }

    if (scalar(@faqs) == 1) {
      $html .= qq(<p><a href="/Help/Faq" class="modal_link">More FAQs</a></p>);
    }
  }

  $html .= qq(<p style="margin-top:1em">If you have any other questions about Ensembl, please do not hesitate to 
<a href="/Help/Contact" class="modal_link">contact our HelpDesk</a>. You may also like to subscribe to the 
<a href="/info/about/contact/mailing.html" class="cp-external">developers' mailing list</a>.</p>);

  return $html;
}

1;
