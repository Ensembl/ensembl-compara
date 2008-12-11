package EnsEMBL::Web::TmpFile::Text;

## EnsEMBL::Web::TmpFile::Text - module for dealing with temporary text files
## see base module for more information

use strict;
use File::Copy qw(move);

use base 'EnsEMBL::Web::TmpFile';

## Accessor for the filename for just uploaded file
__PACKAGE__->mk_accessors('tmp_filename');

sub new {
  my $class = shift;
  my %args  = @_;

  my $self = $class->SUPER::new(
    compress     => 1,
    extension    => 'txt',
    content_type => 'plain/text',
    %args,
  );
  
  if ($args{tmp_filename}) {
    move($args{tmp_filename}, $self->filename) or die "Move failed: $!";
    $self->retrieve;
  }

  return $self;
}

1;