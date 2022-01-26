=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Document::HTML::Compara::SpeciesTree;

## Stub - avoids having the speciestree.html page in the widgets plugin,
## which then cannot be removed in sites that are not multi-species

sub render {
  my $self  = shift;

  return qq(<div class="top-margin bottom-margin">
<b>In order to see the dynamic species tree, you need to have the widgets plugin enabled. Alternatively you can download the tree as a static PDF from the above link.</b>
</div>);

}

1;
