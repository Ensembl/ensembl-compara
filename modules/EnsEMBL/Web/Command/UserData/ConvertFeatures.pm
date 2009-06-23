package EnsEMBL::Web::Command::UserData::ConvertFeatures;

use strict;
use warnings;

use Class::Std;
use Data::Dumper;
use EnsEMBL::Web::RegObj;
use base 'EnsEMBL::Web::Command';
use EnsEMBL::Web::Component::Export;
use Bio::EnsEMBL::DnaDnaAlignFeature;

{

sub process {
  my $self = shift;
  my $object = $self->object;
  my $url = '/'.$object->data_species.'/UserData/PreviewConvert';
  my $param;
  ## Set these separately, or they cause an error if undef
  $param->{'_referer'} = $object->param('_referer');
  $param->{'x_requested_with'} = $object->param('x_requested_with');
  $param->{'_time'} = $object->param('_time');
  my @ids = ($object->param('convert_file'));
  my ($old_name, $old_version, $new_name, $new_version) = split(':', $object->param('conversion'));

  my $sa    = $object->get_adaptor('get_SliceAdaptor', 'core', $object->species);
  my $temp_files = [];
  my $gaps;

  foreach my $id (@ids) {

    ## Get data for remapping
    next unless $id;
    my ($file, $name) = split(':', $id);
    my $data = $object->fetch_userdata_by_id($file);
    my (@fs, $class, $output);

    if (my $parser = $data->{'parser'}) {
      foreach my $track ($parser->{'tracks'}) {
        foreach my $type (keys %{$track}) {
          my $features = $parser->fetch_features_by_tracktype($type);
          ## Convert each feature into a proper API object
          foreach (@$features) {
            my $ddaf = Bio::EnsEMBL::DnaDnaAlignFeature->new($_->cigar_string);
            $ddaf->species($object->species);
            $ddaf->start($_->rawstart);
            $ddaf->end($_->rawend);
            $ddaf->strand($_->strand);
            $ddaf->seqname($_->_seqname);
            $ddaf->score($_->external_data->{'score'}[0]);
            $ddaf->extra_data($_->external_data);
            push @fs, $ddaf;
          }
        }
      }
    }
    elsif ($data->{'features'}) {
      @fs = @{$data->{'features'}};
    }
    my $cs = $object->database('core',$object->species)->get_CoordSystemAdaptor->fetch_by_name($new_name, $new_version);

    ## Loop through features
    my $line;
    my $current_slice;
    ## NB - this next bit only works for GFF export!
    my @skip = qw(_type source feature_type score frame);
    my $skip = join('|', map {'^'.$_.'$'} @skip);

    foreach my $f (@fs) {    
      ## Set feature slice object to one from core database, so we can map cleanly on current db
      ## N.B. Don't create new object unless we need to! Also use a whole seq region for efficiency
      if ($f->slice) {
        unless ($current_slice 
          && $f->slice->seq_region_name eq $current_slice->seq_region_name
        ) {
          $current_slice = $sa->fetch_by_region(undef, $f->slice->seq_region_name);
        } 
      }
      else {
        unless ($current_slice 
          && $f->seqname eq $current_slice->seq_region_name
          ) {
          $current_slice = $sa->fetch_by_region(undef, $f->seqname);
        } 
      }
      $f->slice($current_slice);
      my $new_feature = $f->transform($new_name, $new_version);
      if ($new_feature) {
        my $extra = {};
        my $other = [];
        while (my ($k, $v) = each(%{$f->extra_data})) {
          next if $k =~ /$skip/;
          push @$other, $k;
          $extra->{$k} = $v->[0];
        }
        $line = EnsEMBL::Web::Component::Export::feature($f->extra_data->{'feature_type'}[0],
          {'format' => 'gff', 'delim' => "\t", 'other' => $other}, 
          $new_feature, $extra, $f->extra_data->{'source'}[0]
        );
      }
      else {
        $line = 'GAP';
        $gaps++;
      }
      $output .= $line;
    }
    
    ## Output new data to temp file
    my $temp_file = EnsEMBL::Web::TmpFile::Text->new(
        extension => 'gff',
        prefix => 'export',
        content_type => 'text/plain; charset=utf-8',
      );

    $temp_file->print($output);
    push @$temp_files, $temp_file->filename.':'.$name;
  }
  $param->{'converted'} = $temp_files;
  $param->{'gaps'} = $gaps;

  if ($object->param('x_requested_with')) {
    $self->ajax_redirect($url, $param);
  }
  else {
    $object->redirect($self->url($url, $param));
  }

}


}

1;
