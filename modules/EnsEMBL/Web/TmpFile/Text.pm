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
    tmp_filename => undef,         ## for user uploaded files
    prefix       => 'user_upload',
    extension    => 'txt',
    content_type => 'plain/text',
    drivers      => EnsEMBL::Web::TmpFile::Driver::Disk->new,
    %args,
  );
  
  if ($args{tmp_filename}) {
    open TMP_FILE, $args{tmp_filename};
    local $/;
    $self->{content} = do {local $/; <TMP_FILE> };
    close TMP_FILE;
    unlink $args{tmp_filename};
  }

  return $self;
}

1;