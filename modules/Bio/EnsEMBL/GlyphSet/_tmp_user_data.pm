package Bio::EnsEMBL::GlyphSet::_tmp_user_data;

use strict;

use EnsEMBL::Web::File::Text;

use base qw(Bio::EnsEMBL::GlyphSet::_alignment);

sub features {
  my $self = shift;
  my $data_source = $self->my_config( 'url' ) ;

  my $format = $self->my_config('format');
  my @data = ();
  if( $data_source eq 'tmp' ) {
    my $file = new EnsEMBL::Web::File::Text($self->species_defs);
    my @data = split /[\r\n]+/, $file->retrieve( $self->my_config('filename') );
    foreach( @data ) {
      
    }
  }
  return [];
}

1;
