=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Object::UserData;

### NAME: EnsEMBL::Web::Object::UserData
### Object for accessing data uploaded by the user

### PLUGGABLE: Yes, using Proxy::Object 

### STATUS: At Risk

### DESCRIPTION
### This module does not wrap around a data object, it merely
### accesses user data via the session                                                                                   
use strict;

use Data::Dumper;
use Digest::MD5 qw(md5_hex);

use Bio::EnsEMBL::StableIdHistoryTree;
use Bio::EnsEMBL::Utils::Exception qw(try catch);

use Bio::EnsEMBL::Variation::Utils::VEP qw(
  parse_line
  get_slice
  validate_vf
  get_all_consequences
  @OUTPUT_COLS
  @REG_FEAT_TYPES
  @VEP_WEB_CONFIG
);

use Bio::EnsEMBL::Variation::DBSQL::VariationFeatureAdaptor;
use Bio::EnsEMBL::Variation::DBSQL::StructuralVariationFeatureAdaptor;
use Bio::EnsEMBL::Variation::DBSQL::TranscriptVariationAdaptor;

use EnsEMBL::Web::Cache;
use EnsEMBL::Web::Data::Session;
use EnsEMBL::Web::Document::Table;
use EnsEMBL::Web::File::Utils::IO qw/delete_file/;
use EnsEMBL::Web::File::Utils::FileSystem qw/create_path copy_files/;
use EnsEMBL::Web::Utils::Encryption qw/encrypt_value/;

use base qw(EnsEMBL::Web::Object);

sub data      :lvalue { $_[0]->{'_data'}; }
sub data_type :lvalue {  my ($self, $p) = @_; if ($p) {$_[0]->{'_data_type'} = $p} return $_[0]->{'_data_type' }; }

sub caption  {
  my $self = shift;
  return 'Personal Data';
}

sub short_caption {
  my $self = shift;
  return 'Personal Data';
}

sub counts {
  my $self   = shift;
  my $user   = $self->user;
  my $counts = {};
  return $counts;
}

sub availability {
  my $self = shift;
  my $hash = $self->_availability;
  $hash->{'has_id_mapping'} = $self->table_info( $self->get_db, 'stable_id_event' )->{'rows'} ? 1 : 0;
  return $hash;
}

############### CUSTOM DATA MANAGEMENT #########################

sub rename_session_record {
  my $self = shift;
  my $hub  = $self->hub;
  my $name = $hub->param('value');

  $hub->session->set_data(type => $hub->param('source'), code => $hub->param('code'), name => $name) if $name;
  return 1;
}

sub rename_user_record {
  my $self  = shift;
  my $hub   = $self->hub;
  my $user  = $hub->user;
  my $name  = $hub->param('value');

  if ($name) {
    my ($id, $checksum) = split '-', $hub->param('id');
    my $record = $user->get_record($id);

    if ($checksum eq md5_hex($record->code)) {
      $record->name($name);
      $record->save(user => $user->rose_object);
    }
  }

  return 1;
}

sub save_upload {
## Move an uploaded file to a persistent directory
  my $self = shift;
  my $hub  = $self->hub;
  my $user = $hub->user;

  if ($user) {
    my ($old_path, $new_path) = $self->_move_to_user('upload');
    ## Now move file
    if ($old_path && $new_path) {
      ## Create path to new destination
      my $tmp_dir = $hub->species_defs->ENSEMBL_TMP_DIR;
      my @path_elements = split('/', $new_path);
      pop @path_elements;
      my $dir = join ('/', @path_elements);
      create_path($tmp_dir.'/'.$dir, {'no_exception' => 1});
      ## Set full paths
      my $copied = copy_files({$tmp_dir.'/'.$old_path => $tmp_dir.'/'.$new_path}, {'no_exception' => 1});
      if ($copied) {
        my $result = delete_file($tmp_dir.'/'.$old_path, {'nice' => 1, 'no_exception' => 1});
        if ($result->{'error'}) {
          warn "!!! ERROR ".@{$result->{'error'}};
        }
      }
    }
  }
  else {
    $self->_set_error_message('uploaded data');
  }
  return undef;
}

sub save_remote {
## Move the session record for an attached file to the user record
  my $self = shift;
  my $hub  = $self->hub;
  my $user = $hub->user;

  if ($user) {
    $self->_move_to_user('url');
  }
  else {
    $self->_set_error_message('information about your attached data');
  }
  return undef;
}

sub delete_upload {
### Delete file and session/user record for an uploaded file
  my $self = shift;
  my $hub  = $self->hub;

  my $rel_path = $self->_delete_record('upload');
  if ($rel_path) {
    ## Also remove file
    my $tmp_dir = $hub->species_defs->ENSEMBL_TMP_DIR;
    my $result = delete_file($tmp_dir.'/'.$rel_path, {'nice' => 1, 'no_exception' => 1});
    if ($result->{'error'}) {
      warn "!!! ERROR ".@{$result->{'error'}};
    }
  } 
  return undef;
}

sub delete_remote {
### Delete record for an attached file
  my $self = shift;
  $self->_delete_record('url');
  return undef;
}

sub _set_error_message {
## Add a message to session
  my ($self, $text) = @_;
  my $hub = $self->hub;
  $hub->session->set_data(
      type     => 'message',
      code     => 'user_not_logged_in',
      message  => "Please log in (or create a user account) if you wish to save this $text.",
      function => '_error'
  );
}

sub _move_to_user {
  my ($self, $type) = @_;
  $type     ||= 'url';
  my $hub     = $self->hub;
  my $user    = $hub->user;
  return unless $user;
  my $session = $hub->session;
  my %args    = ('type' => $type, 'code' => $hub->param('code'));

  my $data = $session->get_data(%args);
  my ($old_path, $new_path);

  my $record;
  if ($type eq 'upload') {
    ## Work out where we're going to copy the file to, because we need to save this
    ## in the new user record
    $old_path     = $data->{'file'};
    my $user_id   = encrypt_value($user->id);
    ($new_path = $old_path) =~ s/session_(\d+)/user_$user_id/;
    $new_path =~ s/temporary/persistent/;
    $data->{'file'} = $new_path if $new_path;
    $record = $user->add_to_uploads($data);
  }
  else {
    $record = $user->add_to_urls($data);
  }
  
  if ($record) {
    $session->purge_data(%args);
    if ($type eq 'upload') {
      return ($old_path, $new_path); 
    }
  }
  
  return undef;
}

sub _delete_record {
  my ($self, $type) = @_;
  my $hub        = $self->hub;

  my $source     = $hub->param('source');
  my $code       = $hub->param('code');
  my $id         = $hub->param('id');
  my $user       = $hub->user;

  my $session    = $hub->session;
  my $session_id = $session->session_id;
  my ($file, $track_name);

  if ($user && $id) {
    my $checksum;
    ($id, $checksum) = split '-', $id;
    
    my $record = $user->get_record($id);
    
    if ($record) {
      my $check = $record->data->{'code'};
      
      if ($checksum eq md5_hex($check)) {
        ## Capture path to file so we can delete it
        if ($type eq 'upload') {
          $file = $record->data->{'file'};
        }
        ## Now delete record
        $track_name = "${source}_$check";
        $code       = $check;
        $record->delete;
      }
    }
  } else {
    $track_name = $type.'_'.$code;
    my $temp_data = $session->get_data(type => $type, code => $code);

    if ($type eq 'upload') {
      $file = $temp_data->{'file'};
    }

    if ($temp_data->{'format'} eq 'TRACKHUB' && $self->hub->cache) {
      # delete cached hub
      my $url = $temp_data->{'url'};
      my $key = 'trackhub_'.md5_hex($url);
      $self->hub->cache->delete($key);
    }
    $session->purge_data(type => $type, code => $code);
  }
  
  # Remove all shared data with this code and source
  EnsEMBL::Web::Data::Session->search(code => $code, type => $type)->delete_all if $code =~ /_$session_id$/;
  
  $self->update_configs([ $track_name ]) if $track_name;

  return $type eq 'url' ? undef : $file;
}
    
sub update_configs {
  my ($self, $old_tracks, $new_tracks) = @_;
  my $hub            = $self->hub;
  my $session        = $hub->session;
  my $config_adaptor = $hub->config_adaptor;
  my %valid_species  = map { $_ => 1 } $self->species_defs->valid_species;
  my $updated;
  
  foreach my $config (grep $_->{'type'} eq 'image_config', values %{$config_adaptor->all_configs}) {
    my $update;
    
    foreach my $data (scalar(grep $valid_species{$_}, keys %{$config->{'data'}}) ? values %{$config->{'data'}} : $config->{'data'}) {
      foreach my $key (@$old_tracks) {
        my $old_track = delete $data->{$key};
        
        if ($old_track) {
          $data->{$_}{'display'} = $old_track->{'display'} for @$new_tracks;
          
          foreach my $species (keys %{$data->{'track_order'} || {}}) {

            my $new_track_order = [];

            foreach my $order (@{$data->{'track_order'}{$species}}) {
              my $track_regexp = qr/^$key(\.(r|f))?$/;

              if ($order->[0] =~ $track_regexp) {
                for (@$new_tracks) {
                  push @$new_track_order, [ "$_$1", $order->[1] ];
                }
              } elsif ($order->[1] =~ $track_regexp) {
                for (reverse @$new_tracks) {
                  push @$new_track_order, [ $order->[0], "$_$1" ];
                }
              } else {
                push @$new_track_order, $order;
              }
            }

            $data->{'track_order'}{$species} = $new_track_order;
          }
          
          $update  = 1;
          $updated = 1;
        }
      }
    }
    
    $config_adaptor->set_config(%$config) if $update;
  }
  
  if ($updated) {
    my $user       = $hub->user;
    my $favourites = $session->get_data(type => 'favourite_tracks', code => 'favourite_tracks') || {};
    
    if (grep delete $favourites->{'tracks'}{$_}, @$old_tracks) {
      $favourites->{'tracks'}{$_} = 1 for @$new_tracks;
      
      if (scalar keys %{$favourites->{'tracks'}}) {
        $session->set_data(%$favourites);
      } else {
        delete $favourites->{'tracks'};
        $session->purge_data(%$favourites);
      }
      
      $user->set_favourite_tracks($favourites->{'tracks'}) if $user;
    }
  }
}

#---------------------------------- ID history functionality ---------------------------------

sub get_stable_id_history_data {
  my ($self, $file, $size_limit) = @_;
  my $data = $self->hub->fetch_userdata_by_id($file);
  my (@fs, $class, $output, %stable_ids, %unmapped);

  if (my $parser = $data->{'parser'}) { 
    foreach my $track ($parser->{'tracks'}) { 
      foreach my $type (keys %{$track}) {  
        my $features = $parser->fetch_features_by_tracktype($type);
        my $archive_id_adaptor = $self->get_adaptor('get_ArchiveStableIdAdaptor', 'core', $self->species);

        %stable_ids = ();
        my $count = 0;
        foreach (@$features) {
          next if $count >= $size_limit; 
          my $id_to_convert = $_->id;
          my $archive_id_obj = $archive_id_adaptor->fetch_by_stable_id($id_to_convert);
          unless ($archive_id_obj) { 
            $unmapped{$id_to_convert} = 1;
            next;
          }
          my $history = $archive_id_obj->get_history_tree;
          $stable_ids{$archive_id_obj->stable_id} = [$archive_id_obj->type, $history];
          $count++;
        }
      }
    }
  }
  my @data = (\%stable_ids, \%unmapped); 
  return \@data;
}

#------------------------------- Variation functionality -------------------------------
sub calculate_consequence_data {
  my ($self, $file, $size_limit) = @_;

  my $data = $self->hub->fetch_userdata_by_id($file);
  my %slice_hash;
  my %consequence_results;
  my ($f, @snp_effects, @vfs);
  my $count =0;
  my $feature_count = 0;
  my $file_count = 0;
  my $nearest;
  my %slices;
  
  # build a config hash - used by all the VEP methods
  my $vep_config = $self->configure_vep;
 
=pod 
  ## Convert the SNP features into VEP_OUTPUT features
  if (my $parser = $data->{'parser'}){ 
    foreach my $track ($parser->{'tracks'}) {
      foreach my $type (keys %{$track}) { 
        my $features = $parser->fetch_features_by_tracktype($type);
        
        while ( $f = shift @{$features}){
          $file_count++;
          next if $feature_count >= $size_limit; # $size_limit is max number of v to process, if hit max continue counting v's in file but do not process them
          $feature_count++;
          
          # if this is a variation ID or HGVS, we can use VEP.pm method to parse into VFs
          if($f->isa('EnsEMBL::Web::Text::Feature::ID') || $f->isa('EnsEMBL::Web::Text::Feature::VEP_VCF')) {
            push @vfs, grep {&validate_vf($vep_config, $_)} @{parse_line($vep_config, $f->id)};
            next;
          }
          
          # Get Slice
          my $slice = get_slice($vep_config, $f->seqname);
          next unless defined($slice);
          
          unless ($f->can('allele_string')){
            my $html ='The uploaded data is not in the correct format.
              See <a href="/info/website/upload/index.html#Consequence">here</a> for more details.';
            my $error = 1;
            return ($html, $error);
          }
          
          # name for VF can be specified in extra column or made from location
          # and allele string if not given
          my $new_vf_name = $f->extra || $f->seqname.'_'.$f->rawstart.'_'.$f->allele_string;
          
          # Create VariationFeature
          my $vf;
          
          # sv?
          if($f->allele_string !~ /\//) {
            my $so_term;
            
            # convert to SO term
            my %terms = (
              INS  => 'insertion',
              DEL  => 'deletion',
              TDUP => 'tandem_duplication',
              DUP  => 'duplication'
            );
            
            $so_term = defined $terms{$f->allele_string} ? $terms{$f->allele_string} : $f->allele_string;
            
            $vf = Bio::EnsEMBL::Variation::StructuralVariationFeature->new_fast({
              start          => $f->rawstart,
              end            => $f->rawend,
              chr            => $f->seqname,
              slice          => $slice,
              allele_string  => $f->allele_string,
              strand         => $f->strand,
              adaptor        => $vep_config->{svfa},
              variation_name => $new_vf_name,
              class_SO_term  => $so_term,
            });
          }
          
          # normal vf
          else {
            $vf = Bio::EnsEMBL::Variation::VariationFeature->new_fast({
              start          => $f->rawstart,
              end            => $f->rawend,
              chr            => $f->seqname,
              slice          => $slice,
              allele_string  => $f->allele_string,
              strand         => $f->strand,
              map_weight     => 1,
              adaptor        => $vep_config->{vfa},
              variation_name => $new_vf_name,
            });
          }
          
          next unless &validate_vf($vep_config, $vf);
          
          push @vfs, $vf;
        }
        
        foreach my $line(@{get_all_consequences($vep_config, \@vfs)}) {
          foreach (@OUTPUT_COLS) {
            $line->{$_} = '-' unless defined($line->{$_});
          }
          
          $line->{Extra} = join ';', map { $_.'='.$line->{Extra}->{$_} } keys %{ $line->{Extra} || {} };
          
          my $snp_effect = EnsEMBL::Web::Text::Feature::VEP_OUTPUT->new([
            $line->{Uploaded_variation},
            $line->{Location},
            $line->{Allele},
            $line->{Gene},
            $line->{Feature},
            $line->{Feature_type},
            $line->{Consequence},
            $line->{cDNA_position},
            $line->{CDS_position},
            $line->{Protein_position},
            $line->{Amino_acids},
            $line->{Codons},
            $line->{Existing_variation},
            $line->{Extra},
          ]);
          
          push @snp_effects, $snp_effect;
          
          # if the array is "full" or there are no more items in @features
          if(scalar @snp_effects == 1000 || scalar @$features == 0) {
            $count++;
            next if scalar @snp_effects == 0;
            my @feature_block = @snp_effects;
            $consequence_results{$count} = \@feature_block;
            @snp_effects = ();
          }
        }
        
        if(scalar @snp_effects) {
          $count++;
          my @feature_block = @snp_effects;
          $consequence_results{$count} = \@feature_block;
          @snp_effects = ();
        }
      }
    }
    $nearest = $parser->nearest;
  }
=cut
  
  if ($file_count <= $size_limit){
    return (\%consequence_results, $nearest);
  } else {  
    return (\%consequence_results, $nearest, $file_count);
  }
}

sub consequence_data_from_file {
  my ($self, $code) = @_;
  my $results = {};

  my $data = $self->hub->get_data_from_session('upload', $code);
  if (my $parser = $data->{'parser'}){ 
    foreach my $track ($parser->{'tracks'}) {
      foreach my $type (keys %{$track}) { 
        my $vfs = $track->{$type}{'features'};
        $results->{scalar(@$vfs)} = $vfs;
      }
    }
  }
  return $results;
}

sub consequence_table {
  my ($self, $consequence_data) = @_;
  my $hub     = $self->hub;
  my $species = $hub->param('species') || $hub->species;
  my $code    = $hub->param('code');

  my %popups = (
    'var'       => 'What you input (chromosome, nucleotide position, alleles)',
    'location'  => 'Chromosome and nucleotide position in standard coordinate format (chr:nucleotide position or chr:start-end)',
    'allele'    => 'The variant allele used to calculate the consequence',
    'gene'      => 'Ensembl stable ID of the affected gene (e.g. ENSG00000187634)',
    'trans'     => 'Ensembl stable ID of the affected feature (e.g. ENST00000474461)',
    'ftype'     => 'Type of feature (i.e. Transcript, RegulatoryFeature or MotifFeature)',
    'con'       => 'Consequence type of this variant',
    'cdna_pos'  => 'Nucleotide (base pair) position in the cDNA sequence',
    'cds_pos'   => 'Nucleotide (base pair) position in the coding sequence',
    'prot_pos'  => 'Amino acid position in the protein sequence',
    'aa'        => 'All possible amino acids at the position.  This is only given if the variant affects the protein-coding sequence',
    'codons'    => 'All alternative codons at the position.  The position of the variant is highlighted as bold (HTML version) or upper case (text version)',
    'snp'       => 'Known identifiers of variants at that position',
    'extra'     => 'More information',
  );

  my $columns = [
    { key => 'var',      title =>'Uploaded Variation',   help => $popups{'var'}, align => 'center', sort => 'string'        },
    { key => 'location', title =>'Location',             help => $popups{'location'}, align => 'center', sort => 'position_html' },
    { key => 'allele',   title =>'Allele',               help => $popups{'allele'}, align => 'center', sort => 'string'        },
    { key => 'gene',     title =>'Gene',                 help => $popups{'gene'}, align => 'center', sort => 'html'          },
    { key => 'trans',    title =>'Feature',              help => $popups{'trans'}, align => 'center', sort => 'html'          },
    { key => 'ftype',    title =>'Feature type',         help => $popups{'ftype'}, align => 'center', sort => 'html'          },
    { key => 'con',      title =>'Consequence',          help => $popups{'con'}, align => 'center', sort => 'string'        },
    { key => 'cdna_pos', title =>'Position in cDNA',     help => $popups{'cdna_pos'}, align => 'center', sort => 'position'      },
    { key => 'cds_pos',  title =>'Position in CDS',      help => $popups{'cds_pos'}, align => 'center', sort => 'position'      },
    { key => 'prot_pos', title =>'Position in protein',  help => $popups{'prot_pos'}, align => 'center', sort => 'position'      },
    { key => 'aa',       title =>'Amino acid change',    help => $popups{'aa'}, align => 'center', sort => 'none'          },
    { key => 'codons',   title =>'Codon change',         help => $popups{'codons'}, align => 'center', sort => 'none'          },
    { key => 'snp',      title =>'Co-located Variation', help => $popups{'snp'}, align => 'center', sort => 'html'          },
    { key => 'extra',    title =>'Extra',                help => $popups{'extra'}, align => 'left',   sort => 'html'          },
  ];

  my @rows;

  foreach my $feature_set (keys %$consequence_data) {
    foreach my $f (@{$consequence_data->{$feature_set}}) {
      next if $f->id =~ /^Uploaded/;
      
      my $row               = {};
      my $location          = $f->location;
      my $allele            = $f->allele;
      my $url_location      = $f->seqname . ':' . ($f->rawstart - 500) . '-' . ($f->rawend + 500);
      my $uploaded_loc      = $f->id;
      my $feature_id        = $f->feature;
      my $feature_type      = $f->feature_type;
      my $gene_id           = $f->gene;
      my $consequence       = $f->consequence;
      my $cdna_pos          = $f->cdna_position;
      my $cds_pos           = $f->cds_position;
      my $prot_pos          = $f->protein_position;
      my $aa                = $f->aa_change;
      my $codons            = $f->codons;
      my $extra             = $f->extra_col;
      my $snp_id            = $f->snp;
      my $feature_string    = $feature_id;
      my $gene_string       = $gene_id;
      my $snp_string        = $snp_id;
      
      # guess core type from feature ID

      my $core_type = 'otherfeatures' unless $feature_id =~ /^ENS/ and $feature_id !~ /^ENSEST/;
      
      my $location_url = $hub->url({
        species          => $species,
        type             => 'Location',
        action           => 'View',
        r                =>  $url_location,
        contigviewbottom => "variation_feature_variation=normal,upload_$code=normal",
      });
      
      # transcript
      if ($feature_type eq 'Transcript') {
        my $feature_url = $hub->url({
          species => $species,
          type    => 'Transcript',
          action  => 'Summary',
          db      => $core_type,
          t       => $feature_id,
        });
        
        $feature_string = qq{<a href="$feature_url" rel="external">$feature_id</a>};
      }
      # reg feat
      elsif ($feature_id =~ /^ENS.{0,3}R/) {
        my $feature_url = $hub->url({
          species => $species,
          type    => 'Regulation',
          action  => 'Summary',
          rf      => $feature_id,
        });
        
        $feature_string = qq{<a href="$feature_url" rel="external">$feature_id</a>};
      }
      # gene
      elsif ($feature_id =~ /^ENS.{0,3}G/) {
        my $feature_url = $hub->url({
          species => $species,
          type    => 'Gene',
          action  => 'Summary',
          rf      => $feature_id,
        });
        
        $feature_string = qq{<a href="$feature_url" rel="external">$feature_id</a>};
      }
      else {
        $feature_string = $feature_id;
      }

      if ($gene_id ne '-') {
        my $gene_url = $hub->url({
          species => $species,
          type    => 'Gene',
          action  => 'Summary',
          db      => $core_type,
          g       => $gene_id,
        });
        
        $gene_string = qq{<a href="$gene_url" rel="external">$gene_id</a>};
      }
      
      
      $snp_string = '';
      
      if ($snp_id =~ /^\w/){
        
        foreach my $s(split /\,/, $snp_id) {
          my $snp_url =  $hub->url({
            species => $species,
            type    => 'Variation',
            action  => 'Explore',
            v       =>  $s,
          });
          
          $snp_string .= qq{<a href="$snp_url" rel="external">$s</a>,};
        }
        
        $snp_string =~ s/\,$//g;
      }
      
      $snp_string ||= '-';
      
      $consequence =~ s/\,/\,\<br\/>/g;
      
      # format extra string nicely
      $extra = join ";", map {$self->render_sift_polyphen($_); s/(\w+?=)/<b>$1<\/b>/g; $_ } split /\;/, $extra;
      $extra =~ s/;/;<br\/>/g;
      
      $extra =~ s/(ENSP\d+)/'<a href="'.$hub->url({
        species => $species,
        type    => 'Transcript',
        action  => 'ProteinSummary',
        t       =>  $feature_id,
      }).'" rel="external">'.$1.'<\/a>'/e;
      
      #$consequence = qq{<span class="hidden">$ranks{$consequence}</span>$consequence};

      $row->{'var'}      = $uploaded_loc;
      $row->{'location'} = qq{<a href="$location_url" rel="external">$location</a>};
      $row->{'allele'}   = $allele;
      $row->{'gene'}     = $gene_string;
      $row->{'trans'}    = $feature_string;
      $row->{'ftype'}    = $feature_type;
      $row->{'con'}      = $consequence;
      $row->{'cdna_pos'} = $cdna_pos;
      $row->{'cds_pos'}  = $cds_pos;
      $row->{'prot_pos'} = $prot_pos;
      $row->{'aa'}       = $aa;
      $row->{'codons'}   = $codons;
      $row->{'extra'}    = $extra || '-';
      $row->{'snp'}      = $snp_string;

      push @rows, $row;
    }
  }
  
  return EnsEMBL::Web::Document::Table->new($columns, [ sort { $a->{'var'} cmp $b->{'var'} } @rows ], { data_table => '1' });
}

# render a sift or polyphen prediction with colours
sub render_sift_polyphen {
  my ($self, $string) = @_;
  
  my ($type, $pred_string) = split /\=/, $string;
  
  return $string unless $type =~ /SIFT|PolyPhen|Condel/;
  
  my ($pred, $score) = split /\(|\)/, $pred_string;
  
  my %colours = (
    '-'                  => '',
    'probably_damaging'  => 'red',
    'possibly_damaging'  => 'orange',
    'benign'             => 'green',
    'unknown'            => 'blue',
    'tolerated'          => 'green',
    'deleterious'        => 'red',
    'neutral'            => 'green',
    'not_computable_was' => 'blue',
  );
  
  my $rank_str = '';
  
  if(defined($score)) {
    $rank_str = "($score)";
  }
  
  return qq($type=<span style="color:$colours{$pred}">$pred$rank_str</span>);
}

sub configure_vep {
  my $self = shift;
  
  my %vep_config;
  
  # get user defined config from $self->param
  foreach my $param (@VEP_WEB_CONFIG) {
    my $value = $self->param($param);
    $vep_config{$param} = $value unless $value eq 'no' || $value eq '';
  }
  
  # frequency filtering
  if($vep_config{filter_common}) {
    $vep_config{check_frequency} = 1;
    
    # set defaults
    $vep_config{freq_freq}   ||= 0.01;
    $vep_config{freq_filter} ||= 'exclude';
    $vep_config{freq_pop}    ||= '1KG_ALL';
    $vep_config{freq_gt_lt}  ||= 'gt';
  }
  
  # get adaptors
  my $species = $self->param('species') || $self->species;
  
  my %species_dbs =  %{$self->species_defs->get_config($species, 'databases')};
  if (exists $species_dbs{'DATABASE_VARIATION'} ){
    $vep_config{tva} = $self->get_adaptor('get_TranscriptVariationAdaptor', 'variation', $species);
    $vep_config{vfa} = $self->get_adaptor('get_VariationFeatureAdaptor', 'variation', $species);
    $vep_config{svfa} = $self->get_adaptor('get_StructuralVariationFeatureAdaptor', 'variation', $species);
    $vep_config{va} = $self->get_adaptor('get_VariationAdaptor', 'variation', $species);
  } else  { 
    $vep_config{tva} = Bio::EnsEMBL::Variation::DBSQL::TranscriptVariationAdaptor->new_fake($species);
    $vep_config{vfa} = Bio::EnsEMBL::Variation::DBSQL::VariationFeatureAdaptor->new_fake($species);
    $vep_config{svfa} = Bio::EnsEMBL::Variation::DBSQL::StructuralVariationFeatureAdaptor->new_fake($species);
  }

  $vep_config{sa}  = $self->get_adaptor('get_SliceAdaptor', $vep_config{'core_type'}, $species);
  $vep_config{ta}  = $self->get_adaptor('get_TranscriptAdaptor', $vep_config{'core_type'}, $species);
  $vep_config{ga}  = $self->get_adaptor('get_GeneAdaptor', $vep_config{'core_type'}, $species);
  $vep_config{csa} = $self->get_adaptor('get_CoordSystemAdaptor', $vep_config{'core_type'}, $species);
  
  if(defined($vep_config{regulatory})) {
    foreach my $type(@REG_FEAT_TYPES) {
      my $adaptor = $self->get_adaptor('get_'.$type.'Adaptor', 'funcgen', $species);
      if(defined($adaptor)) {
        $vep_config{$type.'_adaptor'} = $adaptor;
      }
      else {
        delete $vep_config{regulatory};
        last;
      }
    }
  }
  
  # set some other values
  $vep_config{database}       = 1;
  $vep_config{gene}           = 1;
  $vep_config{whole_genome}   = 1;
  $vep_config{chunk_size}     = 50000;
  $vep_config{quiet}          = 1;
  $vep_config{failed}         = 0;
  $vep_config{gmaf}           = 1;
  $vep_config{check_alleles}  = 1 if $vep_config{check_existing} eq 'allele';
  $vep_config{check_existing} = 1 if defined($vep_config{check_frequency}) && exists $species_dbs{'DATABASE_VARIATION'};
  
  delete $vep_config{format} if $vep_config{format} eq 'id';
  $vep_config{format} = 'vcf' if $vep_config{format} eq 'vep_vcf';
  
  return \%vep_config;
}

sub format_coords {
  my ($self, $start, $end) = @_;
  
  if(!defined($start)) {
    return '-';
  }
  elsif(!defined($end)) {
    return $start;
  }
  elsif($start == $end) {
    return $start;
  }
  elsif($start > $end) {
    return $end.'-'.$start;
  }
  else {
    return $start.'-'.$end;
  }
}

1;
