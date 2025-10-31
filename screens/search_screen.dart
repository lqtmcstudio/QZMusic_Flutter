import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/music_model.dart';
import '../providers/player_provider.dart';
import '../providers/storage_provider.dart';
import 'player_screen.dart';
import 'package:flutter_js/flutter_js.dart';

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Music> _searchResults = [];
  bool _isSearching = false;

  // SVG 图标映射
  static const Map<String, String> _svgMap = {
    'wy': '<svg t="1760447818877" class="icon" viewBox="0 0 1024 1024" version="1.1" xmlns="http://www.w3.org/2000/svg" p-id="4581" width="200" height="200"><path d="M0 0m184.32 0l655.36 0q184.32 0 184.32 184.32l0 655.36q0 184.32-184.32 184.32l-655.36 0q-184.32 0-184.32-184.32l0-655.36q0-184.32 184.32-184.32Z" fill="#EA3E3C" p-id="4582"></path><path d="M527.616 849.43872a373.6064 373.6064 0 0 1-162.54976-39.00416c-112.36352-55.16288-180.00896-176.29184-172.55424-308.67456 7.41376-130.34496 85.10464-237.4656 202.752-279.552a35.85024 35.85024 0 0 1 24.15616 67.51232c-107.66336 38.49216-150.81472 136.86784-155.29984 216.13568-5.86752 103.51616 46.08 197.79584 132.34176 240.13824 124.69248 60.30336 216.91392 22.35392 260.82304-5.64224 59.8016-38.16448 97.86368-100.01408 96.95232-157.55264-1.024-63.72352-24.064-120.99584-63.27296-157.14304a145.408 145.408 0 0 0-65.5872-35.28704q2.82624 9.76896 5.64224 19.32288c13.38368 45.63968 24.94464 85.05344 25.6 114.40128a134.26688 134.26688 0 0 1-37.69344 97.76128 139.1104 139.1104 0 0 1-100.6592 40.45824 140.10368 140.10368 0 0 1-100.47488-42.24 169.12384 169.12384 0 0 1-46.2848-122.76736c1.19808-85.12512 80.11776-153.28256 162.816-175.104a324.80256 324.80256 0 0 1-6.71744-67.05152 92.0576 92.0576 0 0 1 69.18144-91.81184c46.21312-12.53376 104.448 5.19168 124.66176 37.888a35.84 35.84 0 0 1-11.70432 49.31584 35.84 35.84 0 0 1-49.26464-11.65312 62.34112 62.34112 0 0 0-48.45568-5.21216c-4.32128 1.71008-12.35968 4.90496-12.76928 23.10144a270.87872 270.87872 0 0 0 6.73792 58.51136 217.4976 217.4976 0 0 1 133.56032 57.6512c53.57568 49.38752 85.0432 125.46048 86.35392 208.71168 1.29024 81.85856-49.7664 167.86432-130.048 219.136a310.14912 310.14912 0 0 1-168.2432 48.65024z m23.6544-457.55392c-56.77056 15.6672-107.4688 63.03744-108.07296 106.42432a98.304 98.304 0 0 0 25.6512 71.43424 68.0448 68.0448 0 0 0 49.36704 20.87936 67.24608 67.24608 0 0 0 49.44896-18.944 63.19104 63.19104 0 0 0 17.23392-46.08c-0.4096-19.79392-11.7248-58.368-22.67136-95.6928-3.61472-12.42112-7.35232-25.14944-10.9568-38.02112z" fill="#FFFFFF" p-id="4583" data-spm-anchor-id="a313x.search_index.0.i1.5fb83a81ePI6Vm"></path></svg>',
    'kw': '<svg t="1760447999068" class="icon" viewBox="0 0 1024 1024" version="1.1" xmlns="http://www.w3.org/2000/svg" p-id="1785" width="200" height="200"><path d="M0 0m174.7656 0l674.4688 0q174.7656 0 174.7656 174.7656l0 674.4688q0 174.7656-174.7656 174.7656l-674.4688 0q-174.7656 0-174.7656-174.7656l0-674.4688q0-174.7656 174.7656-174.7656Z" fill="#F4D329" p-id="1786"></path><path d="M154.01256 137.260106l68.760073 68.270001s7.391083 23.41343-6.901011 32.284729c0 0-39.925849 34.004981-28.344152 74.920975 0 0 4.680686 31.794657 50.027328 45.096606 0 0 24.393573 1.480217 30.314441-2.710397 0 0 44.856571-25.87379 50.027328-60.628881 0 0 5.420794-17.002491-6.901011-41.156029L210.450828 147.121551s34.995126-13.061913 46.576823-48.797148c0 0 9.361371-38.935703-4.930723-57.668448 0 0-4.44065-5.910866-11.33166 0 0 0-28.834224 26.613899-44.356497 29.324296 0 0-8.381228 3.700542-14.052059 2.46036 0 0-12.571842 0-25.633755 12.571842 0 0-22.923358 27.604044-2.710397 52.247653z" fill="#00C9FD" p-id="1787"></path><path d="M95.353968 331.768599s-25.133682 66.729775-30.804513 153.972554c0 0-5.060741 133.329531 11.091625 196.168736 0 0 23.993515 99.314548 50.027328 134.309674 0 0 46.826859 72.70065 94.633863 98.824477 0 0 79.111589 47.316931 135.049783 56.18823 0 0 46.576823 11.581697 89.213068 13.31195h150.582058s126.178483-20.703033 146.631479-34.995126c0 0 111.146281-45.596679 153.292455-123.958158 0 0 56.438267-92.663574 62.839205-184.096967 0 0 12.321805-122.477941 2.960434-174.975631 0 0-13.551985-119.527509-39.185741-161.913718 0 0-37.705523-98.684456-138.750324-153.092426 0 0-84.042311-47.756996-185.577184-52.687718 0 0-182.366714-17.252527-275.030288 21.443141 0 0-12.321805 6.220911-13.061913 18.732744 0 0-0.830122 12.071768 9.811437 21.193105 0 0 8.181198 5.670831 18.77275 4.190614 0 0 80.831841-22.183249 116.317038-19.712888 0 0 176.205811-5.170757 213.421263 13.802022 0 0 87.732851 23.41343 127.408664 58.898628 0 0 60.128808 46.826859 86.752707 116.817111 0 0 27.844079 57.058358 32.034693 158.653241 0 0 3.700542 120.327626-5.420794 152.85239 0 0-13.802022 82.312057-35.735235 122.477941 0 0-31.294584 77.631372-119.527509 122.978015 0 0-30.554476 24.503589-144.171118 41.706109 0 0-97.594296 13.852029-187.547473 0 0 0-102.525018-4.000586-187.297436-67.329863 0 0-69.720213-41.116023-103.995234-165.114186 0 0-26.863935-106.855653-17.252527-189.217718 0 0 1.070157-94.193798 19.962924-140.280549l9.121336-27.354007s1.720252-18.732744-18.232671-25.87379c0 0-20.943068-3.830561-28.344152 14.102066z" fill="#FD6000" p-id="1788"></path><path d="M496.872784 407.179645l-69.750217 69.570191s-25.173688 16.902476-24.633609 74.61093c0 0-0.150022 24.993661 27.974098 56.628295l66.409728 65.799639s2.340343 60.768902-61.489007 86.472666c0 0-60.048796 27.684055-112.716511-29.664345 0 0-16.542423-14.022054-20.853055-47.636978V395.19789s14.20208-67.839937 77.721385-78.621517c0 0 50.067334-8.151194 83.522235 20.13295 0 0 40.405919 35.955267 33.814953 70.470322z" fill="#FD6000" p-id="1789"></path><path d="M443.66499 507.814387l163.353929-162.483801s42.776266-36.435337 100.254686-12.221791c0 0 34.385037 12.461825 53.237798 49.377233 0 0 20.292973 38.355618 1.84027 80.781834 0 0-8.631264 18.212668-17.742599 27.564037l-49.587264 48.927167 53.31781 54.147932s28.144123 31.4046 20.472999 74.550921c0 0-0.960141 41.466074-47.937022 72.390604 0 0-33.074845 23.733477-87.252781 9.35137 0 0-2.880422-0.720105-23.013371-13.421967L450.726024 580.014963s-27.324003-26.673907-7.071035-72.190575z" fill="#FD6000" p-id="1790"></path></svg>',
    'mg': '<svg t="1760448014021" class="icon" viewBox="0 0 1024 1024" version="1.1" xmlns="http://www.w3.org/2000/svg" p-id="1711" width="200" height="200"><path d="M972.8 51.2c-35.84-33.28-74.24-51.2-122.88-51.2H174.08C102.4 0 33.28 48.64 10.24 115.2 2.56 135.68 0 156.16 0 176.64v673.28c0 76.8 51.2 143.36 117.76 163.84 5.12 2.56 7.68 2.56 12.8 5.12h768c2.56-5.12 7.68-5.12 12.8-7.68 51.2-20.48 87.04-53.76 102.4-107.52 0-2.56 2.56-5.12 7.68-7.68V128c-12.8-28.16-25.6-56.32-48.64-76.8zM176.64 675.84c0 5.12-2.56 10.24-2.56 15.36-17.92 12.8-28.16 12.8-46.08 0-5.12-5.12-10.24-7.68-15.36-12.8-35.84-40.96-38.4-128-10.24-171.52 7.68-10.24 15.36-17.92 28.16-25.6 20.48-10.24 28.16-7.68 46.08 7.68 0 2.56 2.56 7.68 2.56 10.24-2.56 58.88-2.56 117.76-2.56 176.64z m611.84-46.08l-2.56 2.56c-10.24 51.2-33.28 97.28-69.12 135.68-102.4 110.08-289.28 115.2-396.8 7.68-43.52-43.52-69.12-92.16-81.92-151.04-5.12-35.84-2.56-69.12 0-104.96 10.24-46.08 28.16-87.04 58.88-122.88 46.08-56.32 104.96-89.6 176.64-102.4 33.28-2.56 66.56-2.56 97.28 2.56 46.08 12.8 87.04 30.72 122.88 61.44 53.76 46.08 87.04 102.4 97.28 174.08 0 2.56 2.56 5.12 2.56 7.68v2.56c0-2.56 0-2.56 2.56-5.12v2.56c0 2.56 0 2.56-2.56 5.12v53.76c-2.56 7.68-2.56 20.48-5.12 30.72z m10.24 58.88s0 2.56 2.56 2.56c-2.56 0-2.56 0-2.56-2.56z m25.6 17.92c-12.8 2.56-17.92-5.12-23.04-15.36v-97.28c0-38.4 5.12-79.36-2.56-117.76-5.12-71.68-35.84-130.56-87.04-181.76-35.84-35.84-79.36-61.44-130.56-71.68-12.8-5.12-25.6-5.12-38.4-7.68-10.24-2.56-15.36 2.56-15.36 12.8V256c0 23.04-7.68 30.72-30.72 28.16-10.24-5.12-15.36-15.36-12.8-28.16v-23.04c2.56-12.8-2.56-17.92-17.92-15.36-120.32 20.48-220.16 122.88-235.52 245.76-7.68 48.64-2.56 94.72-2.56 143.36 0 30.72 5.12 61.44-2.56 89.6-17.92 12.8-25.6 10.24-40.96-5.12v-33.28c0-56.32 2.56-115.2 0-171.52 5.12-71.68 28.16-138.24 74.24-194.56C368.64 151.04 588.8 128 724.48 248.32c66.56 58.88 104.96 130.56 115.2 217.6v202.24c0 5.12 0 12.8 2.56 17.92-2.56 12.8-7.68 20.48-17.92 20.48z m99.84-43.52c-7.68 12.8-17.92 23.04-28.16 33.28-17.92 10.24-30.72 10.24-43.52-7.68-2.56-66.56-2.56-133.12 0-197.12 17.92-15.36 33.28-15.36 56.32 0 12.8 10.24 23.04 25.6 28.16 43.52 10.24 43.52 7.68 84.48-12.8 128z" fill="#CE046D" p-id="1712"></path><path d="M386.56 481.28c-17.92-5.12-28.16 7.68-35.84 20.48 0 0-2.56 0-2.56 2.56-7.68-10.24-12.8-23.04-28.16-23.04-15.36 0-20.48 10.24-30.72 17.92 0-20.48-15.36-12.8-23.04-15.36-12.8 0-10.24 10.24-10.24 15.36v130.56c0 15.36 5.12 17.92 20.48 17.92 15.36 0 17.92-7.68 17.92-20.48v-81.92c0-7.68 2.56-15.36 10.24-17.92 7.68-2.56 10.24 7.68 12.8 12.8 0 33.28-2.56 66.56 2.56 102.4 2.56 2.56 5.12 2.56 10.24 2.56 25.6 0 25.6 0 25.6-23.04v-74.24c0-7.68 2.56-20.48 12.8-20.48s10.24 10.24 12.8 20.48v87.04c0 10.24 5.12 12.8 15.36 10.24 7.68-2.56 20.48 5.12 20.48-10.24 0-40.96 2.56-81.92-2.56-122.88-5.12-10.24-10.24-25.6-28.16-30.72zM532.48 532.48c0-10.24-2.56-15.36-12.8-15.36-20.48 0-20.48 0-20.48 20.48v33.28c0 10.24 0 20.48-2.56 30.72-2.56 5.12-5.12 10.24-12.8 10.24s-10.24-5.12-10.24-12.8v-15.36-58.88c0-10.24-5.12-12.8-12.8-10.24-10.24 5.12-25.6-2.56-25.6 12.8 0 33.28-2.56 66.56 0 99.84 2.56 12.8 7.68 23.04 20.48 25.6 12.8 2.56 23.04 0 33.28-10.24 2.56-2.56 2.56-5.12 2.56-7.68 5.12 23.04 20.48 15.36 30.72 15.36 12.8 0 7.68-10.24 7.68-17.92 2.56-30.72 2.56-66.56 2.56-99.84zM601.6 570.88c-7.68-2.56-12.8-2.56-20.48-5.12-5.12-2.56-10.24-7.68-5.12-12.8s10.24-5.12 15.36-2.56c2.56 2.56 2.56 5.12 5.12 5.12 10.24 5.12 20.48 2.56 28.16 0 7.68-2.56 2.56-10.24 0-15.36-7.68-15.36-20.48-20.48-35.84-17.92-28.16 0-38.4 10.24-43.52 33.28-5.12 23.04 5.12 40.96 30.72 48.64 7.68 2.56 12.8 2.56 20.48 7.68 7.68 2.56 7.68 7.68 5.12 15.36-5.12 5.12-10.24 7.68-15.36 2.56-2.56-2.56-5.12-7.68-7.68-10.24-10.24-7.68-20.48-2.56-30.72 0-7.68 2.56-2.56 10.24 0 15.36 7.68 20.48 30.72 28.16 53.76 20.48 20.48-5.12 30.72-20.48 30.72-43.52 0-23.04-10.24-35.84-30.72-40.96zM783.36 604.16c-10.24-5.12-20.48-12.8-28.16 2.56-2.56 5.12-5.12 12.8-12.8 10.24-7.68 0-10.24-5.12-10.24-12.8-5.12-12.8-5.12-25.6 0-40.96 5.12-15.36 12.8-17.92 23.04-5.12 7.68 10.24 15.36 2.56 23.04 0 7.68 0 5.12-7.68 2.56-12.8-5.12-15.36-12.8-28.16-30.72-30.72-20.48-2.56-33.28 2.56-43.52 23.04-12.8 25.6-10.24 53.76-2.56 81.92 2.56 12.8 10.24 23.04 23.04 28.16 12.8 2.56 25.6 2.56 35.84-2.56l15.36-23.04v-2.56c2.56-5.12 10.24-10.24 5.12-15.36zM657.92 519.68c-7.68-2.56-12.8 2.56-12.8 10.24v112.64c10.24 10.24 20.48 5.12 30.72 2.56 5.12-40.96 2.56-79.36 2.56-120.32 0-12.8-12.8-5.12-20.48-5.12z m17.92 35.84c0 2.56 0 2.56 0 0zM663.04 468.48c-12.8 0-17.92 5.12-17.92 17.92 0 10.24 0 20.48 15.36 17.92 15.36 2.56 17.92-2.56 17.92-17.92 2.56-12.8 0-17.92-15.36-17.92z" fill="#CE046D" p-id="1713"></path></svg>',
    'tx': '<svg t="1760448028815" class="icon" viewBox="0 0 1024 1024" version="1.1" xmlns="http://www.w3.org/2000/svg" p-id="1581" width="200" height="200"><path d="M35.84 529.92c0 263.68 215.04 478.72 478.72 478.72 263.68 0 478.72-215.04 478.72-478.72C993.28 266.24 780.8 51.2 514.56 51.2 250.88 51.2 35.84 266.24 35.84 529.92z" fill="#F8C913" p-id="1582"></path><path d="M660.48 10.24c-17.92 20.48-56.32 38.4-107.52 51.2-87.04 20.48-104.96 25.6-130.56 40.96-15.36 7.68-33.28 20.48-43.52 30.72-20.48 17.92-35.84 51.2-30.72 61.44 2.56 5.12 51.2 74.24 110.08 158.72 58.88 81.92 115.2 163.84 128 181.76 12.8 17.92 20.48 33.28 20.48 33.28 0 2.56-10.24 0-20.48-2.56-40.96-12.8-112.64 0-163.84 25.6-38.4 20.48-81.92 64-99.84 99.84-20.48 40.96-23.04 97.28-7.68 135.68 15.36 40.96 48.64 74.24 92.16 97.28 33.28 17.92 40.96 17.92 84.48 20.48 35.84 2.56 56.32 0 76.8-5.12 94.72-28.16 163.84-102.4 168.96-189.44 2.56-48.64-2.56-64-66.56-176.64-99.84-174.08-189.44-332.8-189.44-335.36 0 0 17.92-2.56 40.96-5.12 66.56-2.56 120.32-35.84 148.48-89.6 12.8-23.04 12.8-30.72 12.8-79.36 0-30.72-2.56-58.88-5.12-61.44-2.56-7.68-5.12-5.12-17.92 7.68z" fill="#02B053" p-id="1583"></path></svg>',
    'kg': '<svg t="1760448043945" class="icon" viewBox="0 0 1024 1024" version="1.1" xmlns="http://www.w3.org/2000/svg" p-id="1608" width="200" height="200"><path d="M328.178326 0h367.600683c114.128578 0 155.51352 11.860839 197.239782 34.174576a232.608975 232.608975 0 0 1 96.763968 96.763968c22.313737 41.726261 34.174576 83.111204 34.174576 197.239782v367.600683c0 114.128578-11.860839 155.51352-34.174576 197.239782a232.608975 232.608975 0 0 1-96.763968 96.763968c-41.726261 22.313737-83.111204 34.174576-197.239782 34.174576H328.178326c-114.128578 0-155.51352-11.860839-197.239782-34.174576A232.608975 232.608975 0 0 1 34.174576 892.976126C11.860839 851.292529 0 809.907587 0 695.779009V328.178326c0-114.128578 11.860839-155.51352 34.174576-197.239782A232.608975 232.608975 0 0 1 130.981209 34.174576C172.664806 11.860839 214.049748 0 328.178326 0z m163.961168 85.799092c-119.163035 4.693138-234.699554 62.845381-309.789759 155.385525A422.851715 422.851715 0 0 0 85.329778 508.992125a422.425066 422.425066 0 0 0 50.00325 204.023499 429.678097 429.678097 0 0 0 137.380942 152.313654A424.174326 424.174326 0 0 0 514.666556 938.627557a424.942294 424.942294 0 0 0 224.075996-65.10662 428.270155 428.270155 0 0 0 167.45969-198.263739c33.363943-79.698013 41.043623-169.635599 22.740385-253.984084-23.892338-112.293988-95.825341-213.11112-193.783925-272.88463a425.624932 425.624932 0 0 0-243.019208-62.546727z m0.426649 53.032457a373.317778 373.317778 0 0 1 202.359568 47.272697 374.72572 374.72572 0 0 1 170.232907 203.554185c26.196242 74.748885 27.04954 157.860089 3.711846 233.419607a373.957752 373.957752 0 0 1-136.954294 190.968043 371.525853 371.525853 0 0 1-222.924045 71.591684 370.331236 370.331236 0 0 1-210.252572-66.727886 372.464481 372.464481 0 0 1-143.738011-195.746511 376.688305 376.688305 0 0 1-1.322612-218.316237 374.597725 374.597725 0 0 1 141.647431-197.410441 370.97121 370.97121 0 0 1 197.197117-68.605141zM369.136619 309.576434c-13.951419 135.077038-26.750885 270.282072-40.872963 405.316445 33.278613 0.469314 66.514562-0.127995 99.75051 0.34132 13.52477-135.333028 28.926795-270.495396 42.067581-405.828424-33.619933 0.682638-67.28253 0.383984-100.945128 0.170659z m218.657556 27.390859c-35.198533 34.814549-72.146327 67.879838-106.576892 103.505021-18.857881 20.735136-34.47323 48.339319-29.950752 77.266114 1.407941 20.351152 12.756802 37.971751 24.190992 54.184409 33.491938 47.187367 64.893296 95.825341 98.129244 143.183367 42.750219-0.213324 85.500437 0.17066 128.250656-0.17066-41.384942-52.691138-81.575268-106.363568-121.936252-159.865339-9.940919-13.823424-22.399067-27.945502-23.593684-45.694096-1.706596-15.487355 9.300946-28.158827 19.11387-38.654389 54.269739-53.75776 108.880797-107.088871 162.894547-161.102621-40.446315 0.511979-80.892629 0.213324-121.338945 0.042665-9.898254 8.916962-19.412524 18.217908-29.182784 27.305529z" fill="#008AD4" p-id="1609"></path></svg>',
  };

  void _search(String keyword) async {
    if (keyword.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }
    setState(() {
      _isSearching = true;
    });

    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final currentSource = playerProvider.musicSource;
    final sourceCode = MusicSourceConfig.getCode(currentSource);

    print('使用音源 ${MusicSourceConfig.getName(currentSource)} 搜索: $keyword');

    try {
      JavascriptRuntime? runtime;
      try {
        final depends = r"""async function customFetch(url, options = {}) {
    const method = options.method || 'GET';
    const headers = options.headers || {};
    return new Promise((resolve, reject) => {
        const xhr = new XMLHttpRequest();
        xhr.open(method, url);
        for (let key in headers) {
            if (Object.prototype.hasOwnProperty.call(headers, key)) {
                xhr.setRequestHeader(key, headers[key]);
            }
        }
        xhr.onload = () => {
            if (xhr.status >= 200 && xhr.status < 300) {
                try {
                    const data = JSON.parse(xhr.responseText);
                    resolve(JSON.stringify(data));
                } catch (e) {
                    reject(new Error('JSON解析错误: ' + e.message));
                }
            } else {
                reject(new Error('HTTP error! status: ' + xhr.status));
            }
        };
        xhr.onerror = () => reject(new Error('Network error'));
        xhr.send(options.body || null);
    });
}""";
        runtime = getJavascriptRuntime(forceJavascriptCoreOnAndroid: false);
        runtime.evaluate(depends);
        // Search_API_JS
        final searchJs = r"""async function _searchKuwoMusic(keyword, number) {
    const baseUrl = "https://api.cenguigui.cn/api/music/kuwo/KoWo_Dg.php";

    const encodedKeyword = encodeURIComponent(keyword);
    const encodedNumber = encodeURIComponent(number);

    const url = `${baseUrl}?type=text&msg=${encodedKeyword}&num=${encodedNumber}&type=json`;

    try {
        const responseJsonString = await customFetch(url);
        const result = JSON.parse(responseJsonString);

        if (result.code !== 200 || !Array.isArray(result.data)) {
            console.error("酷我音乐API返回错误或数据结构不正确:", result);
            return JSON.stringify([]); // 返回空数组的 JSON 字符串
        }

        const songList = result.data;

        // 格式化数据
        const formattedList = songList.map(song => {
            const songRid = song.song_rid;
            return {
                id: songRid,
                source: "kuwo",
                name: song.songname,
                artists: song.singer,
                pic: `https://api.cenguigui.cn/api/kuwo/?rid=${songRid}&type=pic`
            };
        });

        return JSON.stringify(formattedList); // <--- 改动点：返回 JSON 字符串

    } catch (error) {
        console.error("搜索酷我音乐时发生错误:", error.message || error);
        return JSON.stringify([]); // 发生错误时返回空数组的 JSON 字符串
    }
}
async function _searchNeteaseMusic(keyword, number) {
    const baseUrl = "https://oiapi.net/api/Music_163";

    const encodedKeyword = encodeURIComponent(keyword);
    // 网易云 API (oiapi.net) 没有提供 num 参数，因此我们只在客户端限制结果数量
    const url = `${baseUrl}?name=${encodedKeyword}`;

    try {
        const responseJsonString = await customFetch(url);
        const result = JSON.parse(responseJsonString);

        if (result.code !== 0 || !Array.isArray(result.data)) {
            console.error("网易云API返回错误或数据结构不正确:", result);
            return JSON.stringify([]); // 返回空数组的 JSON 字符串
        }

        const songList = result.data;

        // 格式化数据并限制返回数量
        const formattedList = songList.slice(0, number).map(song => {
            // 将 singers 数组中的名字连接成字符串
            const artists = Array.isArray(song.singers)
                ? song.singers.map(s => s.name).join(' / ')
                : '';

            return {
                id: song.id.toString(),
                source: "netease",
                name: song.name,
                artists: artists,
                pic: song.picurl
            };
        });

        return JSON.stringify(formattedList); // <--- 改动点：返回 JSON 字符串

    } catch (error) {
        console.error("搜索网易云音乐时发生错误:", error.message || error);
        return JSON.stringify([]); // 发生错误时返回空数组的 JSON 字符串
    }
}
async function _searchQQMusic(keyword, number) {
    // 请注意：该 API 密钥是硬编码在 URL 中的，建议在生产环境中通过更安全的方式管理密钥。
    const apiKey = "62ccfd8be755cc5850046044c6348d6cac5ef31bd5874c1352287facc06f94c4";
    const baseUrl = "https://cyapi.top/API/qq_music.php";

    const encodedKeyword = encodeURIComponent(keyword);
    // 限制 num 最大为 50
    const finalNumber = Math.min(number, 50);
    const encodedNumber = encodeURIComponent(finalNumber);

    const url = `${baseUrl}?apikey=${apiKey}&msg=${encodedKeyword}&type=json&num=${encodedNumber}`;

    try {
        const responseJsonString = await customFetch(url);
        const result = JSON.parse(responseJsonString);

        // QQ 音乐 API (cyapi.top) 成功的返回码通常为 200 或没有 code 字段，
        // 主要检查 list 字段是否存在且为数组
        if (!Array.isArray(result.list)) {
            console.error("QQ音乐API返回数据结构不正确:", result);
            return JSON.stringify([]); // 返回空数组的 JSON 字符串
        }

        const songList = result.list;

        // 格式化数据
        const formattedList = songList.map(song => {
            return {
                id: song.id,
                source: "qq",
                name: song.name,
                artists: song.artists, // API 直接返回字符串
                pic: song.cover
            };
        });

        return JSON.stringify(formattedList); // <--- 改动点：返回 JSON 字符串

    } catch (error) {
        console.error("搜索 QQ 音乐时发生错误:", error.message || error);
        return JSON.stringify([]); // 发生错误时返回空数组的 JSON 字符串
    }
}
async function _searchKuGouMusic(keyword, number) {
    const baseUrl = "http://mobilecdn.kugou.com/api/v3/search/song";

    const encodedKeyword = encodeURIComponent(keyword);
    const encodedNumber = encodeURIComponent(number);

    // KuGou API 默认返回 JSON 格式
    const url = `${baseUrl}?format=json&keyword=${encodedKeyword}&page=1&pagesize=${encodedNumber}&showtype=1`;

    try {
        const responseJsonString = await customFetch(url);
        const result = JSON.parse(responseJsonString);

        // 检查 API 返回码和数据结构
        if (result.status !== 1 || result.errcode !== 0 || !result.data || !Array.isArray(result.data.info)) {
            console.error("酷狗音乐API返回错误或数据结构不正确:", result);
            return JSON.stringify([]); // 返回空数组的 JSON 字符串
        }

        const songList = result.data.info;

        // 格式化数据
        const formattedList = songList.map(song => {
            // 从 trans_param 中获取封面 URL 模板，并替换 {size} 为合适的值（例如 240）
            // 如果 union_cover 缺失，则使用空字符串
            const picTemplate = song.trans_param && song.trans_param.union_cover ? song.trans_param.union_cover : '';
            const picUrl = picTemplate ? picTemplate.replace('{size}', '240') : '';

            return {
                id: song.hash, // 使用 hash 作为歌曲唯一 ID
                source: "kugou",
                name: song.songname,
                artists: song.singername,
                pic: picUrl
            };
        });

        return JSON.stringify(formattedList); // <--- 改动点：返回 JSON 字符串

    } catch (error) {
        console.error("搜索酷狗音乐时发生错误:", error.message || error);
        return JSON.stringify([]); // 发生错误时返回空数组的 JSON 字符串
    }
}
async function _searchMiGuMusic(keyword, number) {
    const baseUrl = "https://pd.musicapp.migu.cn/MIGUM2.0/v1.0/content/search_all.do";

    const encodedKeyword = encodeURIComponent(keyword);

    // 完整的 URL 构建：
    const url = `${baseUrl}?&ua=Android_migu&version=5.0.1&text=${encodedKeyword}&searchSwitch={"song":1,"album":0,"singer":0,"tagSong":0,"mvSong":0,"songlist":0,"bestShow":1}`;

    try {
        const responseJsonString = await customFetch(url);
        const result = JSON.parse(responseJsonString);

        // 检查 API 返回码和数据结构
        if (result.code !== "000000" || !result.songResultData || !Array.isArray(result.songResultData.result)) {
            console.error("咪咕音乐API返回错误或数据结构不正确:", result);
            return JSON.stringify([]); // 返回空数组的 JSON 字符串
        }

        const songList = result.songResultData.result;

        // 格式化数据并限制返回数量
        const formattedList = songList.slice(0, number).map(song => {
            // 歌手名处理：从 singers 数组中提取 name 并用 ' / ' 连接
            const artists = Array.isArray(song.singers)
                ? song.singers.map(s => s.name).join(' / ')
                : '';

            // 封面图处理：选择第一个 imgItems 中的图片（通常是 imgSizeType: '01'）
            const pic = Array.isArray(song.imgItems) && song.imgItems.length > 0
                ? song.imgItems[0].img
                : '';

            return {
                id: song.contentId, // 使用 contentId 作为歌曲唯一 ID
                source: "migu",
                name: song.name,
                artists: artists,
                pic: pic
            };
        });

        return JSON.stringify(formattedList); // <--- 改动点：返回 JSON 字符串

    } catch (error) {
        console.error("搜索咪咕音乐时发生错误:", error.message || error);
        return JSON.stringify([]); // 发生错误时返回空数组的 JSON 字符串
    }
}
async function searchMusic(source, keyword, number) {
    let resultPromise;

    switch (source) {
        case 'kw':
            resultPromise = _searchKuwoMusic(keyword, number);
            break;
        case 'wy':
            resultPromise = _searchNeteaseMusic(keyword, number);
            break;
        case 'tx':
            resultPromise = _searchQQMusic(keyword, number);
            break;
        case 'kg':
            resultPromise = _searchKuGouMusic(keyword, number);
            break;
        case 'mg':
            resultPromise = _searchMiGuMusic(keyword, number);
            break;
        default:
            console.error(`不支持的音乐源: ${source}`);
            return Promise.resolve(JSON.stringify([])); // <--- 返回空数组的 JSON 字符串
    }

    // searchMusic 函数直接返回内部搜索函数返回的 JSON 字符串 Promise
    return resultPromise;
}""";
        runtime.evaluate(searchJs);
        final String callCode = 'searchMusic("$sourceCode","$keyword",50)';
        JsEvalResult jsResult = await runtime.evaluateAsync(callCode);
        runtime.executePendingJob();
        JsEvalResult asyncResult = await runtime.handlePromise(jsResult);
        final result = asyncResult.stringResult;
        if (result.isEmpty) {
          debugPrint('EmptyThing!!!!');
          setState(() {
            _isSearching = false;
          });
          return;
        }
        List<Music> results = [];
        final songsData = json.decode(result);
        for(var item in songsData) {
          results.add(Music(
              name: item['name'] ?? '',
              artist: item['artists'] ?? '',
              pic: item['pic'] ?? '',
              id: item['id'] ?? '',
              source: sourceCode
          ));
        }
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      } catch(e){
        debugPrint('Dart Error$e');
      } finally {
        runtime?.dispose();
      }
    } catch (e) {
      print('搜索错误: $e');
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _switchMusicSource() {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final currentSource = playerProvider.musicSource;
    final sources = MusicSourceConfig.sources;
    final currentIndex = sources.indexOf(currentSource);
    final nextIndex = (currentIndex + 1) % sources.length;
    final nextSource = sources[nextIndex];
    playerProvider.setMusicSource(nextSource);
    setState(() {
      // 可选：切换音源后清空搜索结果
      _searchResults = [];
      _search(_searchController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playerProvider = Provider.of<PlayerProvider>(context);
    final currentMusic = playerProvider.currentMusic;
    final currentSource = playerProvider.musicSource;
    final currentCode = MusicSourceConfig.getCode(currentSource);

    //final bottomMargin = currentMusic != null ? 70.0 : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          style: TextStyle(color: theme.textTheme.bodyLarge?.color),
          decoration: InputDecoration(
            hintText: '搜索歌曲 - ${MusicSourceConfig.getName(playerProvider.musicSource)}',
            hintStyle: TextStyle(color: theme.textTheme.bodySmall?.color),
            border: InputBorder.none,
          ),
          onSubmitted: _search,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () => _search(_searchController.text),
          ),
          IconButton(
            icon: SvgPicture.string(
              _svgMap[currentCode] ?? '',
              width: 24,
              height: 24,
            ),
            onPressed: _switchMusicSource,
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          //margin: EdgeInsets.only(bottom: bottomMargin),
          child: _isSearching
              ? Center(child: CircularProgressIndicator())
              : ListView.builder(
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              Music music = _searchResults[index];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: theme.cardColor,
                child: ListTile(
                  leading: _buildMusicLeading(music, theme, 50),
                  title: Text(
                    music.name,
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  subtitle: Text(
                    music.artist,
                    style: TextStyle(
                      color: theme.textTheme.bodySmall?.color,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'play') {
                        _playMusic(music,context);
                      } else if (value == 'next') {
                        _playNext(music,context);
                      } else if (value == 'download') {
                        _downloadMusic(music);
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'play',
                        child: Text('播放'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'next',
                        child: Text('下一首播放'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'download',
                        child: Text('下载'),
                      ),
                    ],
                  ),
                  onTap: () {
                    _playMusic(music,context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => PlayerScreen()),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // 统一构建音乐leading的方法
  Widget _buildMusicLeading(Music music, ThemeData theme, double size) {
    if (music.hasValidPic) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            music.pic,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildDefaultMusicIcon(theme, size);
            },
          ),
        ),
      );
    } else {
      return _buildDefaultMusicIcon(theme, size);
    }
  }

  // 构建默认音乐图标
  Widget _buildDefaultMusicIcon(ThemeData theme, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.music_note,
        color: theme.primaryColor,
        size: size * 0.5,
      ),
    );
  }

  void _playMusic(Music music, BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    // 先添加到播放列表
    // playerProvider.addToPlaylist(music);

    // 然后播放
    playerProvider.playMusic(music);
  }

  void _playNext(Music music, BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    // 添加到播放列表
    playerProvider.addToPlaylist(music);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已添加到播放列表')),
    );
  }

  void _downloadMusic(Music music) {
    // 下载逻辑
  }
}