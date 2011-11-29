# $Id$

package EnsEMBL::Web::Command::UserData::DropUpload;

use strict;

use EnsEMBL::Web::Text::FeatureParser;
use EnsEMBL::Web::TmpFile::Text;

use base qw(EnsEMBL::Web::Command::UserData);

sub process {
  my $self = shift;
  my $hub  = $self->hub;
  
  return if $hub->input->cgi_error =~ /413/; # TOO BIG
  return unless $hub->param('text');
  
  my $species_defs = $hub->species_defs;
  
  $hub->param('assembly', $species_defs->ASSEMBLY_NAME;
  
  my $upload = $self->upload('text');
  
  if ($upload->{'code'}) {
    my $session = $hub->session;
    my $data    = $session->get_data(code => $upload->{'code'});
    my $parser  = new EnsEMBL::Web::Text::FeatureParser($species_defs, $hub->referer->{'params'}{'r'}[0], $data->{'species'});
    my $format  = $data->{'format'};
    my $formats = $hub->species_defs->REMOTE_FILE_FORMATS;

    return if grep /^$data->{'format'}$/i, @$formats; # large formats aren't parsable
    
    my $size = int($data->{'filesize'} / (1024 ** 2));

    return if $size > 10; # Uncompressed file is too big.
    
    my $content = new EnsEMBL::Web::TmpFile::Text(filename => $data->{'filename'}, extension => $data->{'extension'})->retrieve;
    
    return unless $content;
    
    $parser->parse($content, $data->{'format'});
    
    my $nearest = $parser->nearest;
    
    if ($nearest && $hub->get_adaptor('get_SliceAdaptor')->fetch_by_region('toplevel', split /\W/, $nearest)) {
      $data->{'format'} ||= $parser->format;
      $data->{'style'}    = $parser->style;
      $data->{'nearest'}  = $nearest;

      $session->set_data(%$data);
      
      print $nearest;
    } else {
      $hub->param('code', $upload->{'code'});
      $self->object->delete_upload;
      return;
    }
  }
}

1;