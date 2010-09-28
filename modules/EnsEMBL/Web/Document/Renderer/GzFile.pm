# $Id$

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
