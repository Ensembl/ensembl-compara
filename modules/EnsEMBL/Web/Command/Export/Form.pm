=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Command::Export::Form;

use strict;

use URI::Escape qw(uri_escape);

use JSON qw(from_json);

use EnsEMBL::Web::TmpFile::Tar;
use EnsEMBL::Web::TmpFile::Text;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self      = shift;
  my $hub       = $self->hub;
  my $function  = $hub->function;
  my %settings  = map { my $val = $hub->param($_); ($_ => $val) } $hub->param;

  $settings{'view_config'} = from_json($settings{'view_config'} || "{}");

  $hub->get_viewconfig({component => 'Export', type => $function, cache => 1})->update_from_input(\%settings);
  $hub->session->store;

  my $url    = $hub->url({ action => 'Formats', function => $function });
  my $params = $self->get_formats;

  $self->ajax_redirect($url, $params);
}

# Returns either the location of temp files for vista/pipmaker export, or a url based on the input parameters for other types
sub get_formats {
  my $self        = shift;
  my $hub         = $self->hub;
  my $object      = $self->object;
  my $output      = $hub->param('output');
  my $strand      = $hub->param('strand');
  my $r           = $hub->param('r');
  my $flank5      = $hub->param('flank5_display');
  my $flank3      = $hub->param('flank3_display');
  my $config      = $object->config;
  my $check_slice = 1;

  my ($old_region,$old_start,$old_end) = split /[:-]/,$r;
  my ($new_region,$new_start,$new_end) = 
    map { $hub->param($_) } qw(new_region new_start new_end);
  $new_region = $old_region unless defined $new_region;
  $new_start = $old_start unless defined $new_start;
  $new_end = $old_end unless defined $new_end;
  unless($new_region eq $old_region and
         $old_start  == $new_start and
         $old_end    == $new_end) {
    # Flip start and end if end is less than start
    ($new_end,$new_start) = ($new_start,$new_end) if($new_end < $new_start);
    
    $r = sprintf("%s:%s-%s",$new_region,$new_start,$new_end);
    $check_slice =
      $object->check_slice($new_region, $new_start, $new_end, $strand);
  }
  
  my $params = {};
  
  if ($check_slice) {
    my $href = $hub->url({ 
      r              => $r,
      strand         => $strand, 
      output         => $output,
      flank5_display => $flank5,
      flank3_display => $flank3,
      type           => 'Export/Output',
      action         => $hub->function
    });
    
    my $map = { 
      csv      => 'features',
      tab      => 'features',
      gff      => 'features',
      gff3     => 'features',
      gtf      => 'features',
      bed      => 'bed',      
      psl      => 'psl',
      embl     => 'flat',
      genbank  => 'flat',
      pipmaker => 'pip',
      vista    => 'pip',
    };
    
    my $key = $map->{$output} || $output;
    my $checked_params = {};
    
    foreach (@{$config->{$key}->{'params'}}) {
      $checked_params->{"${output}_$_->[0]"} = 1;
      
      if ($hub->param("${output}_$_->[0]") eq 'yes') {
        $_->[0] =~ s/(miscset_)//;
        
        $href .= $1 ? ";misc_set=$_->[0]" : ";param=$_->[0]";
      }
    }
    
    foreach (grep { /${output}_/ } $hub->param) {
      (my $param = $_) =~ s/${output}_//;
      $href .= ";$param=" . $hub->param($_) unless $checked_params->{$_};
    }
    
    $params = $key eq 'pip' ? $self->make_temp_files : { base_url => uri_escape($href) };
  }
  
  $params->{'slice'} = !!$check_slice; # boolean
  
  return $params;
}

sub make_temp_files {
  my $self   = shift;  
  my $output = $self->hub->param('output');

  my $seq_file = EnsEMBL::Web::TmpFile::Text->new(
    extension    => 'fa',
    prefix       => 'export',
    content_type => 'text/plain; charset=utf-8'
  );
  
  my $anno_file = EnsEMBL::Web::TmpFile::Text->new(
    filename     => $seq_file->filename,
    extension    => 'txt',
    prefix       => 'export',
    content_type => 'text/plain; charset=utf-8'
  );
    
  $self->export_file($seq_file, 'seq');
  $self->export_file($anno_file, $output);
  
  $seq_file->save;
  $anno_file->save;
  
  my $tar_file = EnsEMBL::Web::TmpFile::Tar->new(
    filename        => $seq_file->filename,
    prefix          => 'export',
    use_short_names => 1
  );
  
  $tar_file->add_file($seq_file);
  $tar_file->add_file($anno_file);
  $tar_file->save;
  
  return {
    seq_file  => uri_escape($seq_file->URL),
    anno_file => uri_escape($anno_file->URL),
    tar_file  => uri_escape($tar_file->URL)
  };
}


sub export_file {
  my $self = shift;
  my ($file, $o) = @_;
  
  my $outputs = {
    seq      => sub { $self->pip_seq_file($file);  },
    pipmaker => sub { $self->pip_anno_file($file, $o); },
    vista    => sub { $self->pip_anno_file($file, $o); }
  };
  
  warn "Invalid file format: $o" and return unless $outputs->{$o};
  
  $outputs->{$o}();
}

sub pip_seq_file {
  my $self = shift;
  my $file = shift;
  
  my $slice = $self->slice;
  
  (my $seq = $slice->seq) =~ s/(.{60})/$1\r\n/g;
  my $name = $slice->name;
  my $fh;
  
  if (ref $file) {
    $fh = $file;
  } else {
    open $fh, ">$file";
  }

  print $fh ">$name\r\n$seq";

  close $fh unless ref $file;
}

sub pip_anno_file {
  my $self = shift;
  my ($file, $o) = @_;
  
  my $slice = $self->slice;  
  my $slice_length = $slice->length;
  my $content = 0;
  my $fh;
  
  my $outputs = {
    pipmaker => sub { return $self->pip_anno_file_pipmaker(@_); },
    vista    => sub { return $self->pip_anno_file_vista(@_); }
  };
  
  if (ref $file) {
    $fh = $file;
  } else {
    open $fh, ">$file";
  }
  
  foreach my $gene (@{$slice->get_all_Genes(undef, undef, 1) || []}) {
    my $gene_header = join ' ', $gene->strand == 1 ? '>' : '<', $gene->start, $gene->end, $gene->external_name || $gene->stable_id, "\r\n";
    
    foreach my $transcript (@{$gene->get_all_Transcripts}) {
      # get UTR/exon lines
      my @exons = @{$transcript->get_all_Exons};
      @exons    = reverse @exons if ($gene->strand == -1);
      
      my $out = $outputs->{$o}($transcript, \@exons);
      # write output to file if there are exons in the exported region
      print $fh "$gene_header$out" and $content = 1 if $out;
    }
  }
  
  print $fh 'No data available' unless $content;
  
  close $fh unless ref $file;
}


sub pip_anno_file_vista {
  my $self = shift;
  my ($transcript, $exons) = @_;
  
  my $coding_start = $transcript->coding_region_start;
  my $coding_end = $transcript->coding_region_end;
  my $out;
  
  foreach my $exon (@$exons) {
    if (!$coding_start) {                                    # no coding region at all
      $out .= join ' ', $exon->start, $exon->end, "UTR\r\n";
    } elsif ($exon->start < $coding_start) {                 # we begin with an UTR
      if ($coding_start < $exon->end) {                      # coding region begins in this exon
        $out .= join ' ', $exon->start, $coding_start - 1, "UTR\r\n";
        $out .= join ' ', $coding_start, $exon->end, "exon\r\n";
      } else {                                               # UTR until end of exon
        $out .= join ' ', $exon->start, $exon->end, "UTR\r\n";
      }
    } elsif ($coding_end < $exon->end) {                     # we begin with an exon
      if ($exon->start < $coding_end) {                      # coding region ends in this exon
        $out .= join ' ', $exon->start, $coding_end, "exon\r\n";
        $out .= join ' ', $coding_end + 1, $exon->end, "UTR\r\n";
      } else {                                               # UTR (coding region has ended in previous exon)
        $out .= join ' ', $exon->start, $exon->end, "UTR\r\n";
      }
    } else {                                                 # coding exon
      $out .= join ' ', $exon->start, $exon->end, "exon\r\n";
    }
  }
  return "$out\r\n";
}

sub pip_anno_file_pipmaker {
  my $self = shift;
  my ($transcript, $exons) = @_;
  
  my $coding_start = $transcript->coding_region_start;
  my $coding_end   = $transcript->coding_region_end;
  
  # do nothing for non-coding transcripts
  return unless $coding_start;

  my $out = "+ $coding_start $coding_end\r\n" if $transcript->start < $coding_start || $transcript->end > $coding_end; # UTR line
  $out   .= join ' ', $_->start, $_->end, "\r\n" for @$exons; # exon lines
  
  return "$out\r\n";
}

# Returns the slice, expanded or flipped as required
sub slice {
  my $self   = shift;
  return $self->object->slice;
}

1;
