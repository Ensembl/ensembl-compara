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

package EnsEMBL::Draw::Style::Legend;

=pod
Renders a dataset as a legend, i.e. one or more columns of icons with labels

This module expects data in the following format:

  $data = {
            'entry_order' => [qw(item1 item2 item2)],
            'entries'     => {
                              'item1' => {
                                          'colour' => 'red',
                                          'label'  => 'Item 1',
                                          },
                              'item2' => {
                                          'colour' => 'blue',
                                          'label'  => 'Item 1',
                                          'style'  => 'triangle',
                                          },
  };

Note that 'style' is optional - it's used for icons that are a different shape or pattern
to the usual kind

=cut

1;
