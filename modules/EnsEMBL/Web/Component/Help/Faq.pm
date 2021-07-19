=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

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
  my $id = shift || $hub->param('id') || $hub->param('feedback');
  my $just_faq = shift;
  $id+=0;
  my $html;
  
  my $adaptor = EnsEMBL::Web::DBSQL::WebsiteAdaptor->new($hub);
  my $args;

  my %category_lookup = (
    'archives'       => 'Archives',  
    'genes'          => 'Genes',    
    'assemblies'     => 'Genome assemblies',    
    'comparative'    => 'Comparative genomics',
    'regulation'     => 'Regulation',         
    'variation'      => 'Variation',         
    'data'           => 'Export, uploads and downloads',  
    'z_data'         => 'Other data',          
    'core_api'       => 'Core API',           
    'compara_api'    => 'Compara API',       
    'compara'        => 'Compara API',       
    'variation_api'  => 'Variation API',    
    'regulation_api' => 'Regulation API',  
    'web'            => 'Website',
  );

  if ($id) {
    $args->{'id'} = $id;
  }
  my @faqs = sort {$a->{'category'} cmp $b->{'category'}} @{$adaptor->fetch_faqs($args)}; 

  ## Can't do category via SQL any more, as it has been moved into 'data' 
  my $single_cat = $hub->param('cat');

  if (scalar(@faqs) > 0) {
  
    my $category = '';

    if (scalar(@faqs) == 1) {

      $html .= sprintf('<h3>%s</h3><p>%s</p>', $self->strip_HTML($faqs[0]->{'question'}), $self->parse_help_html($faqs[0]->{'answer'}, $adaptor));
      if (! $just_faq) {
        $html .= qq(<ul><li><a href="/Help/Faq" class="popup">More FAQs</a></li></ul>);
      }
    }
    else {
      $html .= qq(<h2>FAQs</h2>);
      my $division = $hub->species_defs->EG_DIVISION || 'vertebrates';

      foreach my $faq (@faqs) {
        next unless $faq && $faq->{'question'};
        next if $single_cat && $faq->{'category'} ne $single_cat;

        ## Filter out anything that doesn't apply to this site
        my %divisions = map {$_ => 1} @{$faq->{'division'}||[]};
        next if (keys %divisions && !$divisions{$division});

        unless ($single_cat) {
          if ($faq->{'category'} && $category ne $faq->{'category'}) {
            $html .= "</ul>\n\n";
            $html .= '<h3>'.$category_lookup{$faq->{'category'}}."</h3>\n<ul>\n";
          }
        }

        $html .= sprintf(qq(<li><a href="/Help/Faq?id=%s" id="faq%s" class="popup">%s</a></li>\n), $faq->{'id'}, $faq->{'id'}, $self->strip_HTML($faq->{'question'}));
        if ($hub->param('feedback') && $hub->param('feedback') == $faq->{'id'}) {
          $html .= qq(<div>Thank you for your feedback</div>);
        } 
        else {
          $html .= $self->help_feedback($faq->{'id'}, return_url => '/Help/Faq', type => 'Faq');
        }
        $category = $faq->{'category'};
      }
      $html .= '</ul>' if $category;
    }
  }
  if (! $just_faq) {
    $html .= qq(<hr /><p style="margin-top:1em">If you have any other questions about Ensembl, please do not hesitate to 
<a href="/Help/Contact" class="popup">contact our HelpDesk</a>. You may also like to subscribe to the 
<a href="//www.ensembl.org/info/about/contact/mailing.html" class="cp-external">developers' mailing list</a>.</p>);
  }
  return $html;
}

1;
