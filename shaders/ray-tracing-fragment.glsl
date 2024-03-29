uniform vec2 u_resolution;
uniform float u_time;
uniform float u_mousewheel;
uniform vec2 u_pointerdiff;
uniform vec2 u_keymove;

// Constants

const float INFINITY = 10000000.0;
const float PI = 3.14159265;
const int MAX_DEPTH = 50;
const int SAMPLES_PER_PIXEL = 30;
const vec3 GROUND_COLOR = vec3(0.5, 0.5, 0.9);
const float LIGHT_SOURCE_RADIUS = 0.2;

// Meterial Types

const int MATERIAL_LAMBERTIAN = 0;
const int MATERIAL_METAL = 1;
const int MATERIAL_DIELECTRIC = 2;
const int MATERIAL_LIGHT = 3;


// Utility

float variation = 0.00001;
float rand(){
    variation += 0.00001;
    vec2 co = vec2(gl_FragCoord.xy);
    return fract(sin(dot(co, vec2(12.9898+variation, 78.233+variation))) * 43758.5453);
}

float rand(float min, float max) {
  return min + (max-min)*rand();
}

vec3 rand_vec3() {
  return vec3(rand(), rand(), rand());
}

vec3 rand_vec3(float min, float max) {
  return vec3(rand(min, max), rand(min, max), rand(min, max));
}

vec3 random_in_unit_sphere() {
  while (true) {
    vec3 p = rand_vec3(-1.0, 1.0);
    if(length(p) < 1.0)
      return p;
  }
}

vec3 random_in_unit_disk() {
  while (true) {
    vec3 p = vec3(rand(-1.0, 1.0), rand(-1.0, 1.0), 0.0);
    if(length(p) < 1.0)
      return p;
  }
}

vec3 random_unit_vector() {
  return normalize(random_in_unit_sphere());
}

vec3 random_on_hemisphere(vec3 normal) {
  vec3 on_unit_sphere = random_unit_vector();
  if (dot(on_unit_sphere, normal) > 0.0)
    return on_unit_sphere;
  else
    return -on_unit_sphere;
}

bool near_zero(vec3 v) {
  float s = 1e-8;
  return (abs(v.x) < s) && (abs(v.y) < s) && (abs(v.z) < s);
}

vec3 rotate(vec3 v, vec3 axis, float theta) {
  return v * cos(theta) + cross(axis, v) * sin(theta) + axis * dot(axis, v) * (1.0-cos(theta));
}

float degrees_to_radians(float degrees) {
  return degrees * PI / 180.0;
}

float linear_to_gamma(float linear_component) {
  return sqrt(linear_component);
}

struct Interval {
  float min, max;
};

bool interval_contains(Interval interval, float x) {
  return x >= interval.min && x <= interval.max;
}

bool interval_surrounds(Interval interval, float x) {
  return x > interval.min && x < interval.max;
}

float interval_clamp(Interval interval, float x) {
  if (x < interval.min) return interval.min;
  if (x > interval.max) return interval.max;
  return x;
}

Interval empty = Interval(+INFINITY, -INFINITY);
Interval universe = Interval(-INFINITY, +INFINITY);


// Ray

struct Ray {
  vec3 origin;
  vec3 direction;
};

vec3 ray_at(Ray ray, float t) {
  return ray.origin + t*ray.direction;
}


// Material

struct Material {
  int type;
  vec3 albedo;
  float fuzz; // for Metal
  float ir; // Index of Refraction for Dielectric
};

float reflectance(float cosine, float ref_index) {
  // Schlick's approximation
  float r0 = (1.0 - ref_index) / (1.0 + ref_index);
  r0 = r0 * r0;
  return r0 + (1.0-r0) * pow((1.0 - cosine), 5.0);
}


// Intersection Record

struct IntersectionRecord {
  vec3 pos;
  vec3 normal;
  float t;
  bool front_face;
  Material material;
};

void set_intersected_face_normal(inout IntersectionRecord record, Ray ray, vec3 outward_normal) {
  // outward_normal : unit vector

  record.front_face = dot(ray.direction, outward_normal) < 0.0;
  record.normal = record.front_face ? outward_normal : -outward_normal;
}


// Geometry

struct Sphere {
  vec3 center;
  float radius;
  Material material;
};

bool ray_sphere_intersection(Ray ray, Interval ray_t, Sphere s, inout IntersectionRecord record) {
  vec3 co = ray.origin - s.center;
  float a = dot(ray.direction, ray.direction);
  float half_b = dot(co, ray.direction);
  float c = dot(co, co) - s.radius*s.radius;
  
  float discriminant = half_b*half_b - a*c;
  if (discriminant < 0.0) {
    return false;
  }
  float sqrtd = sqrt(discriminant);

  float root = (-half_b - sqrtd) / a;
  if (!interval_surrounds(ray_t, root)) {
    root = (-half_b + sqrtd) / a;
    if (!interval_surrounds(ray_t, root))
      return false;
  }

  record.t = root;
  record.pos = ray_at(ray, record.t);
  vec3 outward_normal = (record.pos - s.center) / s.radius;
  set_intersected_face_normal(record, ray, outward_normal);
  record.material = s.material;
  return true;
}

struct Triangle {
  vec3 p0;
  vec3 p1;
  vec3 p2;
  Material material;
};

bool ray_triangle_intersection(Ray ray, Interval ray_t, Triangle tri, inout IntersectionRecord record) {
  
  const float epsilon = 0.001;


  // compute the triangle normal

  vec3 p0p1 = tri.p1 - tri.p0;
  vec3 p0p2 = tri.p2 - tri.p0;
  vec3 normal = cross(p0p1, p0p2);
  

  // check if the ray and triangle are parallel

  float dot_n_raydir = dot(normal, ray.direction);
  if(abs(dot_n_raydir) < epsilon)
    return false;


  // find p (the intersection point)

  float d = dot(-normal, tri.p0);

  float t = -(dot(normal, ray.origin) + d) / dot_n_raydir;

  if (!interval_surrounds(ray_t, t))
    return false;

  vec3 p = ray_at(ray, t);


  // test p is inside or outside triangle

  vec3 c;

  c = cross(tri.p1-tri.p0, p-tri.p0);
  if (dot(normal, c) < 0.0)
    return false;
  
  c = cross(tri.p2-tri.p1, p-tri.p1);
  if (dot(normal, c) < 0.0)
    return false;
  
  c = cross(tri.p0-tri.p2, p-tri.p2);
  if (dot(normal, c) < 0.0)
    return false;
  

  record.t = t;
  record.pos = p;
  vec3 outward_normal = normal;
  set_intersected_face_normal(record, ray, outward_normal);
  record.material = tri.material;
  return true;
}

struct Tetrahedron {
  vec3 p0;
  vec3 p1;
  vec3 p2;
  vec3 p3;
  Material material;
};

bool ray_tetrahedron_intersection(Ray ray, Interval ray_t, Tetrahedron tet, inout IntersectionRecord record) {
  float closest = INFINITY;
  IntersectionRecord rec_temp;

  bool intersect_something = false;

  if(ray_triangle_intersection(ray, Interval(0.001, closest), Triangle(tet.p2, tet.p1, tet.p0, tet.material), rec_temp)) {
    intersect_something = true;
    closest = rec_temp.t;
  }
  if(ray_triangle_intersection(ray, Interval(0.001, closest), Triangle(tet.p3, tet.p2, tet.p1, tet.material), rec_temp)) {
    intersect_something = true;
    closest = rec_temp.t;
  }
  if(ray_triangle_intersection(ray, Interval(0.001, closest), Triangle(tet.p0, tet.p3, tet.p2, tet.material), rec_temp)) {
    intersect_something = true;
    closest = rec_temp.t;
  }
  if(ray_triangle_intersection(ray, Interval(0.001, closest), Triangle(tet.p1, tet.p0, tet.p3, tet.material), rec_temp)) {
    intersect_something = true;
    closest = rec_temp.t;
  }


  if(!intersect_something)
    return false;

  if (!interval_surrounds(ray_t, closest))
    return false;

  record.t = rec_temp.t;
  record.pos = rec_temp.pos;
  record.material = tet.material;
  vec3 outward_normal = rec_temp.normal;
  set_intersected_face_normal(record, ray, outward_normal);
  return true;
}

// Scatter Ray

bool scatter(Material material, vec3 light_pos, Ray ray_in, IntersectionRecord record, inout vec3 attenuation, inout Ray scattered) {
  
  if (material.type == MATERIAL_LAMBERTIAN) {

    if(rand() < 0.04) {
      // to light source
      vec3 scatter_direction = light_pos - record.pos + LIGHT_SOURCE_RADIUS*random_in_unit_sphere();
      scattered = Ray(record.pos, scatter_direction);
      attenuation = 0.5 * material.albedo;
      return true;
    }

    vec3 scatter_direction = record.normal + random_unit_vector();
    if(near_zero(scatter_direction))
      scatter_direction = record.normal;
    scattered = Ray(record.pos, scatter_direction);
    attenuation = material.albedo;
    return true;

  } else if (material.type == MATERIAL_METAL) {

    if(rand() < 0.04) {
      // to light source
      vec3 scatter_direction = light_pos - record.pos + LIGHT_SOURCE_RADIUS*random_in_unit_sphere();
      scattered = Ray(record.pos, scatter_direction);
      attenuation = 0.5 * material.albedo;
      return true;
    }

    vec3 reflected = reflect(normalize(ray_in.direction), record.normal);
    scattered = Ray(record.pos, reflected + material.fuzz*random_unit_vector());
    attenuation = material.albedo;
    return (dot(scattered.direction, record.normal) > 0.0);

  } else if (material.type == MATERIAL_DIELECTRIC) {

    if(rand() < 0.04) {
      // to light source
      vec3 scatter_direction = light_pos - record.pos + LIGHT_SOURCE_RADIUS*random_in_unit_sphere();
      scattered = Ray(record.pos, scatter_direction);
      attenuation = 0.5 * material.albedo;
      return true;
    }

    attenuation = vec3(1.0, 1.0, 1.0);
    float refraction_ratio = record.front_face ? (1.0/material.ir) : material.ir;

    vec3 unit_direction = normalize(ray_in.direction);
    float cos_theta = min(dot(-unit_direction, record.normal), 1.0);
    float sin_theta = sqrt(1.0 - cos_theta*cos_theta);

    bool cannot_refract = refraction_ratio * sin_theta > 1.0;
    vec3 direction;

    if(cannot_refract || reflectance(cos_theta, refraction_ratio) > rand())
      direction = reflect(unit_direction, record.normal);
    else
      direction = refract(unit_direction, record.normal, refraction_ratio);

    scattered = Ray(record.pos, direction);
    return true;

  }
  else if (material.type == MATERIAL_LIGHT) {
    return false;
  }

  return false;

}

vec3 emit(Material material) {
  if(material.type == MATERIAL_LIGHT) {
    return vec3(1.0, 1.0, 1.0);
  }
  else {
    return vec3(0.0, 0.0, 0.0);
  }
}


// Pixel Color

vec3 ray_color(Ray ray) {
  int max_depth = MAX_DEPTH;

  // World
  vec3 light_pos = vec3(3.3 * sin(u_time * 0.5), 3.3, 3.3 * cos(u_time * 0.5));
  
  Sphere[] sphere_list = Sphere[](
    Sphere(vec3(0.0, -100.2, 0.0), 100.0, Material(MATERIAL_LAMBERTIAN, GROUND_COLOR, 0.1, 1.0)),
    Sphere(light_pos, LIGHT_SOURCE_RADIUS, Material(MATERIAL_LIGHT, vec3(0.2, 0.6, 0.8), 0.0, 1.0)),
    Sphere(vec3(-0.8, 0.3, -1.2), 0.5, Material(MATERIAL_DIELECTRIC, vec3(0.8, 0.8, 0.8), 0.0, 1.5)),
    Sphere(vec3(-0.9, 0.0, -0.4), 0.2, Material(MATERIAL_LAMBERTIAN, vec3(1.0, 0.8, 0.8), 0.0, 1.0)), // pink
    Sphere(vec3(0.8, 0.0, -0.8), 0.2, Material(MATERIAL_DIELECTRIC, vec3(0.8, 0.8, 0.8), 0.3, 1.5)),
    Sphere(vec3(0.55, 0.0, -0.1), 0.2, Material(MATERIAL_LAMBERTIAN, vec3(1.0, 0.2, 0.7), 0.1, 1.5)), // red
    Sphere(vec3(-0.6, 0.0, 0.3), 0.2, Material(MATERIAL_METAL, vec3(1.0, 1.0, 0.4), 0.1, 1.5)), // yellow
    Sphere(vec3(0.3, 0.0, 0.5), 0.2, Material(MATERIAL_METAL, vec3(0.5, 1.0, 0.6), 0.2, 1.5)) // green
  );
  
  Tetrahedron[] tet_list = Tetrahedron[](
    Tetrahedron(vec3(0.0, -0.2, 0.5 * 1.0 / sqrt(3.0) - 0.3),
                vec3(0.5, 0.5 * sqrt(3.0) - 0.2, -0.3),
                vec3(-0.5, 0.5 * sqrt(3.0) - 0.2, -0.3),
                vec3(0.0, 0.5 * sqrt(3.0) - 0.2, 0.5 * sqrt(3.0) - 0.3),
                Material(MATERIAL_METAL, vec3(0.8, 0.8, 0.8), 0.0, 1.5)
                )
  );

  vec3 unit_direction = normalize(ray.direction);
  float a = 0.5*(unit_direction.y + 1.0);
  vec3 final_color = (1.0-a)*vec3(1.0, 1.0, 1.0) + a*vec3(0.5, 0.8, 1.0);

  Ray ray_curr = ray;
  int curr_depth = 0;
  for(curr_depth = 0; curr_depth < max_depth; curr_depth++) {
    IntersectionRecord record;
    IntersectionRecord rec_temp;
    bool intersect_something = false;
    float closest = INFINITY;
    
    // Test Ray-Sphere Intersection
    for (int i=0; i<sphere_list.length(); i++) {
      if(ray_sphere_intersection(ray_curr, Interval(0.001, closest), sphere_list[i], rec_temp)) {
        intersect_something = true;
        closest = rec_temp.t;
        record = rec_temp;
      }
    }

    // Test Ray-Tetrahedron Intersection
    for (int i=0; i<tet_list.length(); i++) {
      if(ray_tetrahedron_intersection(ray_curr, Interval(0.001, closest), tet_list[i], rec_temp)) {
        intersect_something = true;
        closest = rec_temp.t;
        record = rec_temp;
      }
    }
    
    if(!intersect_something)
      break;
    
        
    Ray scattered;
    vec3 attenuation;
    vec3 emission_color = emit(record.material);
    bool is_scattered = scatter(record.material, light_pos, ray_curr, record, attenuation, scattered);

    if(!is_scattered) {
      return emission_color;
    }

    ray_curr = scattered;
    final_color = attenuation * final_color;
  }

  if(curr_depth == max_depth)
    return vec3(0.0, 0.0, 0.0);

  return final_color;
}


// Camera

struct Camera {
  float aspect_ratio;
  int samples_per_pixel;
  vec3 center;
  vec3 pixel_lower_left;
  vec3 pixel_delta_u;
  vec3 pixel_delta_v;
  
  float vfov;
  vec3 look_from;
  vec3 look_at;
  vec3 vup;
  vec3 u, v, w;

  float defocus_angle;
  float focus_dist;
  vec3 defocus_disk_u;
  vec3 defocus_disk_v;
};

void init(inout Camera camera) {
  camera.aspect_ratio = float(u_resolution.y)/float(u_resolution.x);
  camera.samples_per_pixel = SAMPLES_PER_PIXEL;

  camera.vfov = degrees_to_radians(20.0 + 0.5 * u_mousewheel);
  
  camera.look_from = vec3(9.0, 1.6, 2.0);
  camera.look_at = vec3(0.0, 0.0, 0.0);
  camera.vup = vec3(0, 1, 0);

  camera.defocus_angle = 1.0;
  camera.focus_dist = 9.0 + 2.4 * u_keymove.y;


  //  Rotate camera with mouse pointer

  camera.look_from = rotate(camera.look_from, -camera.vup, 0.1 * u_pointerdiff.x);
  camera.center = camera.look_from;

  camera.w = normalize(camera.look_from - camera.look_at);
  camera.u = normalize(cross(camera.vup, camera.w));
  camera.v = cross(camera.w, camera.u);

  float h = tan(camera.vfov/2.0);
  float viewport_height = 2.0 * h * camera.focus_dist;
  float viewport_width = viewport_height / camera.aspect_ratio;

  vec3 viewport_u = viewport_width * camera.u;
  vec3 viewport_v = viewport_height * camera.v;

  camera.pixel_delta_u = viewport_u / u_resolution.x;
  camera.pixel_delta_v = viewport_v / u_resolution.y;

  vec3 viewport_lower_left = camera.center - (camera.focus_dist * camera.w) - viewport_u/2.0 - viewport_v/2.0
                            - viewport_u*0.12; // the last term is error correction

  camera.pixel_lower_left = viewport_lower_left + 0.5 * (camera.pixel_delta_u + camera.pixel_delta_v);

  float defocus_radius = camera.focus_dist * tan(degrees_to_radians(camera.defocus_angle)/2.0);
  camera.defocus_disk_u = camera.u * defocus_radius;
  camera.defocus_disk_v = camera.v * defocus_radius;
}

vec3 pixel_sample_square(Camera camera) {
  float px = -0.5 + rand();
  float py = -0.5 + rand();
  return (px * camera.pixel_delta_u) + (py * camera.pixel_delta_v);
}

vec3 defocus_disk_sample(Camera camera) {
  vec3 p = random_in_unit_disk();
  return camera.center + (p.x * camera.defocus_disk_u) + (p.y * camera.defocus_disk_v);
}

Ray get_ray(Camera camera, float x, float y) {
  vec3 pixel_center = camera.pixel_lower_left + (x * camera.pixel_delta_u) + (y * camera.pixel_delta_v);
  vec3 pixel_sample = pixel_center + pixel_sample_square(camera);

  vec3 ray_origin = camera.defocus_angle <= 0.0 ? camera.center : defocus_disk_sample(camera);
  vec3 ray_direction = pixel_sample - ray_origin;
  return Ray(ray_origin, ray_direction);
}


void main() {
  Camera camera;
  init(camera);

  vec3 pixel_color = vec3(0.0, 0.0, 0.0);
  for(int sample_i = 0; sample_i < camera.samples_per_pixel; sample_i++) {
    Ray ray = get_ray(camera, gl_FragCoord.x, gl_FragCoord.y);
    pixel_color += ray_color(ray);
  }

  float scale = 1.0 / float(camera.samples_per_pixel);
  Interval intensity = Interval(0.000, 0.999);
  float cx = interval_clamp(intensity, pixel_color.x * scale);
  float cy = interval_clamp(intensity, pixel_color.y * scale);
  float cz = interval_clamp(intensity, pixel_color.z * scale);
  cx = linear_to_gamma(cx);
  cy = linear_to_gamma(cy);
  cz = linear_to_gamma(cz);

  pixel_color = vec3(cx, cy, cz);

  gl_FragColor = vec4(pixel_color, 1.0);
}