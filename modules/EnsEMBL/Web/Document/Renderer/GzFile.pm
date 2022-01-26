=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Document::Renderer::GzFile;

use strict;

use Compress::Zlib;

use base qw(EnsEMBL::Web::Document::Renderer EnsEMBL::Web::Root);

sub new {
  my $class    = shift;
  my $filename = shift;
  
  my $self = $class->SUPER::new(
    filename => $filename,
    @_
  );
  
  if (!$self->exists($filename)) {
    ## Here be dragons - export fails unless we make the directory, but no file is saved!
    $self->make_directory($filename);
    $self->{'file'} = gzopen($filename, 'wb') || undef;
  }
  
  $self->r->content_type('application/octet-stream');
  $self->r->headers_out->add('Content-Disposition' => 'attachment; filename=ensembl.txt.gz');
  
  return $self;
}

sub valid  { return $_[0]->{'file'}; }
sub printf { my $self = shift; my $FH = $self->{'file'}; return unless $FH; $FH->gzwrite(sprintf shift, @_); }
sub print  { my $self = shift; my $FH = $self->{'file'}; return unless $FH; $FH->gzwrite($_) for @_; }
sub exists { my $filename = $_[0]->{'filename'}; return $filename && -e $filename && -f $filename; }

sub raw_content {
  my $self = shift;
  open FH, $self->{'filename'};
  local $/ = undef;
  my $content = <FH>;
  close FH;
  return $content;
}

sub content {
  my $self    = shift;
  my $gz      = gzopen($self->{'filename'}, 'rb') || return '';
  my $buffer  = '';
  my $content = '';
  $content   .= $buffer while $gz->gzread($buffer) > 0;
  
  $gz->gzclose;
  
  return $content;
}

sub close   { my $FH = $_[0]->{'file'}; return unless $FH; $FH->gzclose; $_[0]->{'file'} = undef; }
sub DESTROY { my $FH = $_[0]->{'file'}; return unless $FH; $FH->gzclose; }

1;
