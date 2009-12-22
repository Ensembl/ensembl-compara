package EnsEMBL::Web::Document::Renderer::GzFile;

use strict;

use Compress::Zlib;

use base qw(EnsEMBL::Web::Root);

sub new {
  my $class    = shift;
  my $filename = shift;

  my $self = { 'exists' => 'yes' };
  bless $self, $class;
    $self->{ 'filename' } =  $filename;
  return $self if $self->exists( $filename );
  $self->make_directory( $filename );

  $self->{'exists'} = 'no';
  if( my $gz = gzopen( $filename, 'wb' ) ) {
    $self->{'file'} = $gz;
  } else {
    $self->{'file'} = undef;
  }
  return $self;
}

sub valid   { return $_[0]->{'file'}; }
sub printf  { my $self = shift; my $FH = $self->{'file'}; my $template = shift; return unless $FH; $FH->gzwrite( sprintf $template, @_ ); }
sub print   { my $self = shift; my $FH = $self->{'file'}; return unless $FH; foreach(@_) { $FH->gzwrite( $_ ); } }

sub exists  { my $filename = $_[0]->{'filename'}; return $filename && -e $filename && -f $filename; }

sub raw_content {
  my $self = shift;
  open FH, $self->{'filename'};
  local $/ = undef;
  my $content = <FH>;
  close FH;
  return $content;
}

sub content {
  my $self = shift;
  
  my $gz = gzopen( $self->{'filename'}, 'rb' ) || return '';
  my $buffer = '';
  my $content = '';
  $content .= $buffer while $gz->gzread( $buffer ) > 0;
  $gz->gzclose; 
  return $content;
}

sub close   { my $FH = $_[0]->{'file'}; return unless $FH; $FH->gzclose; $_[0]->{'file'} = undef; }
sub DESTROY { my $FH = $_[0]->{'file'}; return unless $FH; $FH->gzclose; }

1;
