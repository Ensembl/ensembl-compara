=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Apache::SSI;

use strict;

use Apache2::Const qw(:common :methods :http);
use Compress::Zlib;

use EnsEMBL::Web::Controller::Doxygen;
use EnsEMBL::Web::Controller::SSI;

#############################################################
# Mod_perl request handler all /htdocs pages
#############################################################
sub handler {
  my ($r, $cookies) = @_;
  my $i = 0;
  ## First of all check that we should be doing something with the page...
  
  ## Pick up DAS entry points requests and
  ## uncompress them dynamically
  
  if (-e $r->filename && -r $r->filename) {
    if ($r->filename =~ /\/entry_points$/) {
      my $gz      = gzopen($r->filename, 'rb');
      my $buffer  = 0;
      my $content = '';
      $content   .= $buffer while $gz->gzread($buffer) > 0;
      
      $gz->gzclose; 
      
      if ($ENV{'PERL_SEND_HEADER'}) {
        print "Content-type: text/xml; charset=utf-8";
      } else {
        $r->content_type('text/xml; charset=utf-8');
      }
      
      $r->print($content);
      
      return OK;
    } elsif ($r->filename =~ /\/Doxygen\/(?!index.html)/ || $r->filename =~ /\/edoc\/index.html/) {
      return EnsEMBL::Web::Controller::Doxygen->new($r, $cookies)->status;
    }
  }

  $r->err_headers_out->{'Ensembl-Error' => 'Problem in module EnsEMBL::Web::Apache::SSI'};
  $r->custom_response(SERVER_ERROR, '/Crash');

  return DECLINED if $r->content_type ne 'text/html';

  my $rc = $r->discard_request_body;
  
  return $rc unless $rc == OK;
  
  if ($r->method_number == M_INVALID) {
    $r->log->error('Invalid method in request ', $r->the_request);
    return HTTP_NOT_IMPLEMENTED;
  }
   
  return DECLINED                if $r->method_number == M_OPTIONS;
  return HTTP_METHOD_NOT_ALLOWED if $r->method_number != M_GET;
  return DECLINED                if -d $r->filename;
  return EnsEMBL::Web::Controller::SSI->new($r, $cookies)->status;
}

1;
