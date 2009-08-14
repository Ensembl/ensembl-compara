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
    my (@fs, $class);

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
            $ddaf->seqname($_->seqname);
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
    my $csa    = $object->database('core',$object->species)->get_CoordSystemAdaptor;
    my $ama    = $object->database('core', $object->species)->get_AssemblyMapperAdaptor;
    my $old_cs = $csa->fetch_by_name($old_name, $old_version);
    my $new_cs = $csa->fetch_by_name($new_name, $new_version);
    my $mapper = $ama->fetch_by_CoordSystems($old_cs, $new_cs);

    ## Loop through features
    ## NB - this next bit only works for GFF export!
    my @skip = qw(_type source feature_type score frame);
    my $skip = join('|', map {'^'.$_.'$'} @skip);
    
    my $exporter = new EnsEMBL::Web::Component::Export;
    $exporter->{'config'} = {
      format => 'gff',
      delim  => "\t"
    };
    my $current_slice;

    foreach my $f (@fs) {    
      my @coords = $mapper->map($f->seqname, $f->start, $f->end, $f->strand, $old_cs);

      foreach my $new (@coords) {
        unless ($current_slice && $f->seqname eq $current_slice->seq_region_name) {
          $current_slice = $sa->fetch_by_seq_region_id($new->id);
        }
        $f->slice($current_slice);

        if (ref($new) =~ /Gap/) {
          $gaps++;
        }
        $f->start($new->start);
        $f->end($new->end);

        my $feature_type = $f->extra_data->{'feature_type'}[0];
        my $source = $f->extra_data->{'source'}[0];

        my $extra = {};
        my $other = [];
        while (my ($k, $v) = each(%{$f->extra_data})) {
          next if $k =~ /$skip/;
          push @$other, $k;
          $extra->{$k} = $v->[0];
        }
        $exporter->{'config'}->{'extra_fields'} = $other;
        $exporter->feature($feature_type, $f, $extra, { 'source' => $source });
      }
    }
    
    my $output = $exporter->string;

    ## Output new data to temp file
    my $temp_file = EnsEMBL::Web::TmpFile::Text->new(
        extension => 'gff',
        prefix => 'export',
        content_type => 'text/plain; charset=utf-8',
      );

    $temp_file->print($output);
    my $converted = $temp_file->filename.':'.$name;
    if ($gaps > 0) {
      $converted .= ':'.$gaps;
    }
    push @$temp_files, $converted;
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

