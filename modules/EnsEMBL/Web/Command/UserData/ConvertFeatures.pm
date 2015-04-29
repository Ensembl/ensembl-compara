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

package EnsEMBL::Web::Command::UserData::ConvertFeatures;

use strict;

use Bio::EnsEMBL::DnaDnaAlignFeature;
use Bio::EnsEMBL::Utils::Exception qw(try catch);

use EnsEMBL::Web::Object::Export;
use EnsEMBL::Web::TmpFile::Text;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self       = shift;
  my $hub        = $self->hub;
  my $object     = $self->object;
  my $session    = $hub->session;
  my $species    = $hub->data_species;
  my $url_params = { action => 'PreviewConvert', __clear => 1, _time => $hub->param('_time') || '' };
  my $sa         = $hub->get_adaptor('get_SliceAdaptor', 'core', $species);
  my @conversion = split ':', $hub->param('conversion');
  my $csa        = $hub->database('core', $species)->get_CoordSystemAdaptor;
  my $ama        = $hub->database('core', $species)->get_AssemblyMapperAdaptor;
  my $old_cs     = $csa->fetch_by_name(shift @conversion, shift @conversion);
  my $new_cs     = $csa->fetch_by_name(shift @conversion, shift @conversion);
  my $mapper     = $ama->fetch_by_CoordSystems($old_cs, $new_cs);
  my $gaps;
  my $error;

  foreach my $id (grep $_, $hub->param('convert_file')) {
    ## Get data for remapping
    my ($file, $name) = split ':', $id;
    my $data     = $hub->fetch_userdata_by_id($file);
    my $parser   = $data->{'parser'};
    my $skip     = join '|', map "^$_\$", qw(_type source feature_type score frame);
    my $exporter = EnsEMBL::Web::Object::Export->new($hub);
    my (@fs, $current_slice, $nearest);
    
    $exporter->{'config'} = {
      format => 'gff',
      delim  => "\t"
    };
    
    if ($parser) {
      foreach my $track ($parser->{'tracks'}) {
        foreach my $type (keys %{$track}) {
          my $features = $parser->fetch_features_by_tracktype($type);
          ## Convert each feature into a proper API object
          foreach (@$features) {
            my $ddaf = Bio::EnsEMBL::DnaDnaAlignFeature->new($_->cigar_string);
            
            $ddaf->species($species);
            $ddaf->start($_->rawstart);
            $ddaf->end($_->rawend);
            $ddaf->strand($_->strand);
            $ddaf->seqname($_->seqname);
            $ddaf->score(exists $_->external_data->{'score'} ? $_->external_data->{'score'}[0] : undef);
            $ddaf->extra_data($_->external_data);
            $ddaf->{'gff_attribs'}=$_->attribs;
            
            push @fs, $ddaf;
          }
        }
      }
    } elsif ($data->{'features'}) {
      @fs = @{$data->{'features'}};
    }
    
    ## Loop through features
    ## NB - this next bit only works for GFF export!
    foreach my $f (@fs) {   
  
      my @coords; 
      try {
        @coords = $mapper->map($f->seqname, $f->start, $f->end, $f->strand, $old_cs);
      } catch {
        warn $_;
        if ($_ =~ /MSG:/) {
          ($error) = $_ =~ m/MSG: (.*)$/m;
        } else {
          $error = $_;
        }
      };
      
      if ($error) {
        $url_params->{'error'} = $error if $error;
      }
      foreach my $new (@coords) {
        if (ref($new) =~ /Gap/) {
          $gaps++;
        } else {
          $current_slice = $sa->fetch_by_seq_region_id($new->id) unless $current_slice && $f->seqname eq $current_slice->seq_region_name;
          
          # get a 100k (scaled by genome size) location around the first feature
          if (!$nearest) {
            my $threshold = 1e5 * ($hub->species_defs->get_config($species, 'ENSEMBL_GENOME_SIZE') || 1);
            my $end       = $current_slice->end;
            my $start     = $new->start;
            my $s = ($start - $threshold/2) + 1;
               $s = 1 if $s < 1;
            my $e = $s + $threshold - 1;
            
            if ($e > $end) {
              $e = $end;
              $s = $e - $threshold - 1;
            }
            
            $nearest = sprintf '%s:%s-%s', $current_slice->seq_region_name, $s, $e;
          }
          
          $f->slice($current_slice);
        }
        
        $f->start($new->start);
        $f->end($new->end);

        my $feature_type = exists $f->extra_data->{'feature_type'} ? $f->extra_data->{'feature_type'}[0] : undef;
        my $source       = exists $f->extra_data->{'source'} ? $f->extra_data->{'source'}[0] : undef;
        my $extra        = $f->{'gff_attribs'};
        my $other        = [];
        
        while (my ($k, $v) = each %{$f->extra_data}) {
          next if $k =~ /$skip/;
          
          push @$other, $k;
          $extra->{$k} = $v->[0];
        }
        push(@$other,keys %{$f->{'gff_attribs'}});
        
        $exporter->{'config'}{'extra_fields'} = $other;
        $exporter->feature($feature_type, $f, $extra, { source => $source });
      }
    }
    
    my $output = $exporter->string;

    ## Output new data to temp file
    my $temp_file = EnsEMBL::Web::TmpFile::Text->new(
      extension    => 'gff',
      prefix       => 'user_upload',
      content_type => 'text/plain; charset=utf-8',
    );
    
    $temp_file->print($output);
    
    $url_params->{'converted'} = join ':', grep $_, $temp_file->filename, $name, $gaps;
    
    my ($type, $code) = split '_', $file, 2;
    my $session_data  = $session->get_data(type => $type, code => $code);
    
    $session_data->{'filename'} = $temp_file->filename;
    $session_data->{'filesize'} = length $temp_file->content;
    $session_data->{'md5'}      = $temp_file->md5;
    $session_data->{'nearest'}  = $nearest;
    
    $session->set_data(%$session_data);
  }
  
  $url_params->{'gaps'} = $gaps if $gaps;

  $self->ajax_redirect($hub->url($url_params));
}

1;
