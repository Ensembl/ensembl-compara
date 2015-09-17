=head1 sLICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::NewTable::NewTable;

use strict;

use JSON qw(from_json);
use Scalar::Util qw(looks_like_number);

use EnsEMBL::Draw::Utils::ColourMap;

use base qw(EnsEMBL::Web::Root);
use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::Utils::RandomString qw(random_string);

use EnsEMBL::Web::Document::NewTableSorts qw(newtable_sort_client_config);

sub new {
  my ($class, $component, $options) = @_;

  $options  ||= {};

  my $self = {
    component  => $component,
    columns    => [],
    options    => $options,
  };

  bless $self, $class;

  $self->preprocess_hyphens;

  return $self;
}

sub has_rows { return ! !@{$_[0]{'rows'}}; }

# \f -- optional hyphenation point
# \a -- optional break point (no hyphen)
sub hyphenate {
  my ($self, $data, $key) = @_;

  return unless exists $data->{$key};

  my $any = ($data->{$key} =~ s/\f/&shy;/g | $data->{$key} =~ s/\a/&#8203;/g);

  return $any;
}

sub preprocess_hyphens {
  my $self = shift;

  foreach (@{$self->{'columns'}}) {
    my $h = $_->{'label'} ? $self->hyphenate($_, 'label') : 0;
    $_->{'class'} .= ' hyphenated' if $h;
  }
}

sub render {
  my ($self,$hub) = @_;

  return unless @{$self->{'columns'}};

  my $options     = $self->{'options'}        || {};
  my %table_class = map { $_ => 1 } split ' ', $options->{'class'};
  my $class   = join ' ', keys %table_class;

  my $url = $hub->url('ComponentAjax', {
    source => 'enstab',
    action => 'Web',
    function => 'VariationTable',
  },0,1);

  my %colmap;
  foreach my $i (0..$#{$self->{'columns'}}) {
    $colmap{$self->{'columns'}[$i]{'key'}} = $i;
  }

  my $sort_conf = newtable_sort_client_config(\%colmap,$self->{'columns'});

  my $orient = {
    pagesize => 10,
    rows => [0,-1],
    columns => [ (1) x scalar(@{$self->{'columns'}}) ],
    format => 'tabular',
  }; # XXX fix me: separate view from orient
  my $data = {
    unique => random_string(32),
    type => $self->{'options'}{'type'}||'',
    cssclass => $class,
    columns => [ map { $_->{'key'} } @{$self->{'columns'}} ],
    head => [
      [ "page_sizer" ],
      [ "loading","columns" ],
      [ "export", "new_table_filter", "search" ],
      [ "filter" ]
    ],
    orient => $orient,
    formats => [ "tabular", "paragraph" ],
    colconf => $sort_conf,
    widgets => {
      export => [ "newtable_export",{}],
      filter => [ "new_table_filter",{}],
      filter_class => ["newtable_filter_class",{}],
      filter_range => ["newtable_filter_range",{}],
      filter_enum => ["newtable_filter_enumclient",{}],
      search => [ "new_table_search",{}],
      clientsort => [ "new_table_clientsort",{}],
      decorate => [ "newtable_decorate", {}],
      decorate_iconic => [ "newtable_decorate_iconic", {}],
      decorate_link => [ "newtable_decorate_link", {}],
      decorate_editorial => [ "newtable_decorate_editorial", {}],
      decorate_also => [ "newtable_decorate_also", {}],
      decorate_toggle => [ "newtable_decorate_toggle", {}],
      page_sizer => ["new_table_pagesize", { "sizes" => [ 0, 10, 100 ] } ],
      "tabular" => [ "new_table_tabular", { } ],
      "paragraph" => [ "new_table_paragraph", { } ],
      "styles" => [
         "new_table_style",
         {
            "styles" => [ [ "tabular", "Tabular" ], [ "paragraph", "Paragraph" ] ]
         }
      ],
      "columns" => [ "new_table_columns", { } ],
      "loading" => [ "new_table_loading", { } ],
   },
  };
  my $payload_one = $self->{'component'}->newtable_data_request($data,$orient,$orient,undef,1);
  $data->{'payload_one'} = $payload_one;

  $data = encode_entities($self->jsonify($data));
  return qq(
    <a class="new_table" href="$url">$data</a>
  );
}

sub add_column {
  my ($self,$key,$options) = @_;

  push @{$self->{'columns'}},{ key => $key, %{$options||{}} };
}

1;
