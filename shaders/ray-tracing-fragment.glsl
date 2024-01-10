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


// Meterial Types

const int MATERIAL_LAMBERTIAN = 0;
const int MATERIAL_METAL = 1;
const int MATERIAL_DIELECTRIC = 2;


// Utility

float variation = 0.00001;
float rand(vec2 co){
    variation += 0.00001;
    return fract(sin(dot(co, vec2(12.9898+variation, 78.233+variation))) * 43758.5453);
}

float rand(vec2 co, float min, float max) {
  return min + (max-min)*rand(co);
}

vec3 rand_vec3(vec2 co) {
  return vec3(rand(co), rand(co), rand(co));
}

vec3 rand_vec3(vec2 co, float min, float max) {
  return vec3(rand(co, min, max), rand(co, min, max), rand(co, min, max));
}

vec3 random_in_unit_sphere(vec2 co) {
  while (true) {
    vec3 p = rand_vec3(co, -1.0, 1.0);
    if(length(p) < 1.0)
      return p;
  }
}

vec3 random_unit_vector(vec2 co) {
  return normalize(random_in_unit_sphere(co));
}

vec3 random_on_hemisphere(vec2 co, vec3 normal) {
  vec3 on_unit_sphere = random_unit_vector(co);
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
  vec3 p1;
  vec3 p2;
  vec3 p3;
};


// Scatter Ray

bool scatter(Material material, Ray ray_in, IntersectionRecord record, inout vec3 attenuation, inout Ray scattered) {
  
  if (material.type == MATERIAL_LAMBERTIAN) {

    vec3 scatter_direction = record.normal + random_unit_vector(vec2(gl_FragCoord.xy));
    if(near_zero(scatter_direction))
      scatter_direction = record.normal;
    scattered = Ray(record.pos, scatter_direction);
    attenuation = material.albedo;
    return true;

  } else if (material.type == MATERIAL_METAL) {

    vec3 reflected = reflect(normalize(ray_in.direction), record.normal);
    scattered = Ray(record.pos, reflected + material.fuzz*random_unit_vector(vec2(gl_FragCoord.xy)));
    attenuation = material.albedo;
    return (dot(scattered.direction, record.normal) > 0.0);

  } else if (material.type == MATERIAL_DIELECTRIC) {

    attenuation = vec3(1.0, 1.0, 1.0);
    float refraction_ratio = record.front_face ? (1.0/material.ir) : material.ir;

    vec3 unit_direction = normalize(ray_in.direction);
    float cos_theta = min(dot(-unit_direction, record.normal), 1.0);
    float sin_theta = sqrt(1.0 - cos_theta*cos_theta);

    bool cannot_refract = refraction_ratio * sin_theta > 1.0;
    vec3 direction;

    if(cannot_refract || reflectance(cos_theta, refraction_ratio) > rand(vec2(gl_FragCoord.xy)))
      direction = reflect(unit_direction, record.normal);
    else
      direction = refract(unit_direction, record.normal, refraction_ratio);

    scattered = Ray(record.pos, direction);
    return true;

  }
  
  return false;

}


// Pixel Color

vec3 ray_color(Ray ray) {
  int max_depth = MAX_DEPTH;

  float R = cos(PI/4.0);

  // World
  Sphere[] sphere_list = Sphere[](
    Sphere(vec3(0.0, -100.5, -1.0), 100.0, Material(MATERIAL_METAL, vec3(0.8, 0.8, 0.8), 0.3, 1.0)),
    Sphere(vec3(-R, 0.0, -1.0), R, Material(MATERIAL_LAMBERTIAN, vec3(0.7, 0.3, 0.3), 0.0, 1.0)),
    Sphere(vec3(R, 0.0, -1.0), R, Material(MATERIAL_DIELECTRIC, vec3(0.8, 0.8, 0.8), 0.3, 1.5)),
    Sphere(vec3(1.0, 0.3 * sin(u_time * 2.0 + 1.0), -1.0), 0.2, Material(MATERIAL_METAL, vec3(0.2, 0.6, 0.8), 1.0, 1.0))
  );

  vec3 unit_direction = normalize(ray.direction);
  float a = 0.5*(unit_direction.y + 1.0);
  vec3 final_color = (1.0-a)*vec3(1.0, 1.0, 1.0) + a*vec3(0.5, 0.7, 1.0);

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

    // Test Ray-Triangle Intersection
    
    
    if(!intersect_something)
      break;
    
        
    Ray scattered;
    vec3 attenuation;
    bool is_scattered = scatter(record.material, ray_curr, record, attenuation, scattered);

    if(!is_scattered)
      return vec3(0.0, 0.0, 0.0);

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
  vec3 look_direction;
  vec3 vup;
  vec3 u, v, w;
};

void init(inout Camera camera) {
  camera.aspect_ratio = u_resolution.y/u_resolution.x;
  camera.samples_per_pixel = SAMPLES_PER_PIXEL;

  camera.vfov = degrees_to_radians(45.0 + u_mousewheel);
  
  camera.look_from = vec3(0, 0, 0);
  camera.look_direction = vec3(0, 0, -2);
  camera.vup = vec3(0, 1, 0);


  camera.w = normalize(-camera.look_direction);
  camera.u = normalize(cross(camera.vup, camera.w));
  camera.v = cross(camera.w, camera.u);

  

  //  Rotate camera with mouse pointer

  camera.look_direction = rotate(normalize(camera.look_direction), -camera.v, 0.1 * u_pointerdiff.x);

  // reset
  camera.w = normalize(-camera.look_direction);
  camera.u = normalize(cross(camera.vup, camera.w));
  camera.v = cross(camera.w, camera.u);

  camera.look_direction = rotate(normalize(camera.look_direction), -camera.u, 0.1 * u_pointerdiff.y);

  // reset
  camera.w = normalize(-camera.look_direction);
  camera.u = normalize(cross(camera.vup, camera.w));
  camera.v = cross(camera.w, camera.u);

  // Move camera with keys
  vec3 keydiff = 0.5 * camera.w * (-u_keymove.y) + camera.u * u_keymove.x;
  camera.look_from += keydiff;
  

  camera.center = camera.look_from;

  float focal_length = length(-camera.look_direction);

  float h = tan(camera.vfov/2.0);
  float viewport_height = 2.0 * h * focal_length;
  float viewport_width = viewport_height / camera.aspect_ratio;

  vec3 viewport_u = viewport_width * camera.u;
  vec3 viewport_v = viewport_height * camera.v;

  camera.pixel_delta_u = viewport_u / u_resolution.x;
  camera.pixel_delta_v = viewport_v / u_resolution.y;

  vec3 viewport_lower_left = camera.center - (focal_length * camera.w) - viewport_u/2.0 - viewport_v/2.0;
  camera.pixel_lower_left = viewport_lower_left + 0.5 * (camera.pixel_delta_u + camera.pixel_delta_v);
}

vec3 pixel_sample_square(Camera camera) {
  float px = -0.5 + rand(vec2(gl_FragCoord.xy));
  float py = -0.5 + rand(vec2(gl_FragCoord.xy));
  return (px * camera.pixel_delta_u) + (py * camera.pixel_delta_v);
}

Ray get_ray(Camera camera, float x, float y) {
  vec3 pixel_center = camera.pixel_lower_left + (x * camera.pixel_delta_u) + (y * camera.pixel_delta_v);
  vec3 pixel_sample = pixel_center + pixel_sample_square(camera);

  vec3 ray_direction = pixel_sample - camera.center;
  return Ray(camera.center, ray_direction);
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