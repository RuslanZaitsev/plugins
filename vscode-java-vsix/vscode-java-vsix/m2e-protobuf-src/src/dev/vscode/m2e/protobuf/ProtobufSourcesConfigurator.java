package dev.vscode.m2e.protobuf;

import java.io.File;
import java.util.List;
import java.util.Properties;

import org.apache.maven.plugin.MojoExecution;
import org.apache.maven.project.MavenProject;
import org.codehaus.plexus.util.xml.Xpp3Dom;
import org.eclipse.core.runtime.CoreException;
import org.eclipse.core.runtime.IPath;
import org.eclipse.core.runtime.IProgressMonitor;
import org.eclipse.core.runtime.ILog;
import org.eclipse.core.runtime.Platform;
import org.eclipse.core.runtime.Status;
import org.eclipse.m2e.core.project.IMavenProjectFacade;
import org.eclipse.m2e.core.project.configurator.ProjectConfigurationRequest;
import org.eclipse.m2e.jdt.IClasspathDescriptor;
import org.eclipse.m2e.jdt.IClasspathEntryDescriptor;
import org.eclipse.m2e.jdt.AbstractSourcesGenerationProjectConfigurator;

/**
 * m2e connector for protoc-based Maven plugins (org.xolstice / io.github.ascopes).
 * <p>
 * Registers the plugin's output directories as JDT source folders WITHOUT running protoc
 * inside the IDE. Sources are produced by a regular {@code mvn generate-sources/compile};
 * the IDE only has to see them. This avoids:
 * <ul>
 * <li>protoc download/execution failures inside the embedded Maven (Nexus, os classifier, AV);</li>
 * <li>the plugin's {@code clearOutputDirectory} wiping already generated classes on a failed run;</li>
 * <li>rebuild loops on every workspace build.</li>
 * </ul>
 * Bound to maven-compiler-plugin (compile/testCompile) rather than to the protobuf plugin itself,
 * so a user/workspace lifecycle mapping that ignores protobuf-maven-plugin cannot switch it off.
 * The protobuf plugin executions are looked up in the project model directly.
 * <p>
 * Directory resolution order: explicit {@code <outputDirectory>} in the POM -&gt; user/project
 * property ({@code javaOutputDirectory}, {@code protocPluginOutputDirectory}) -&gt; plugin default.
 */
public class ProtobufSourcesConfigurator extends AbstractSourcesGenerationProjectConfigurator {

    private static final String BUNDLE_ID = "dev.vscode.m2e.protobuf";

    /** groupId, artifactId, main-source goals. Test goals are intentionally not mapped. */
    private static final String[][] PLUGINS = {
        { "org.xolstice.maven.plugins", "protobuf-maven-plugin", "compile", "compile-custom", "compile-cpp", "compile-python", "compile-js", "compile-csharp", "compile-javanano" },
        { "io.github.ascopes", "protobuf-maven-plugin", "generate" },
    };

    @Override
    public void configureRawClasspath(ProjectConfigurationRequest request, IClasspathDescriptor classpath,
            IProgressMonitor monitor) throws CoreException {
        IMavenProjectFacade facade = request.mavenProjectFacade();
        MavenProject project = request.mavenProject();
        for (String[] p : PLUGINS) {
            String[] goals = java.util.Arrays.copyOfRange(p, 2, p.length);
            List<MojoExecution> executions;
            try {
                executions = facade.getMojoExecutions(p[0], p[1], monitor, goals);
            } catch (CoreException | RuntimeException e) {
                log("cannot read executions of " + p[0] + ":" + p[1], e);
                continue;
            }
            for (MojoExecution execution : executions) {
                File dir;
                try {
                    dir = resolve(project, execution);
                } catch (RuntimeException e) {
                    log("cannot resolve output directory for " + execution, e);
                    continue;
                }
                if (dir == null) {
                    continue;
                }
                if (!dir.exists()) {
                    dir.mkdirs(); // empty folder in target/ so JDT does not flag a missing source folder
                }
                IPath full = getFullPath(facade, dir);
                if (full == null || classpath.containsPath(full)) {
                    continue;
                }
                IClasspathEntryDescriptor e = classpath.addSourceEntry(full, facade.getOutputLocation(), true);
                e.setClasspathAttribute("ignore_optional_problems", "true");
            }
        }
    }

    static File resolve(MavenProject project, MojoExecution execution) {
        String artifactId = execution.getArtifactId();
        String groupId = execution.getGroupId();
        String goal = execution.getGoal();
        File base = project.getBasedir();
        String buildDir = project.getBuild().getDirectory();
        Properties props = mergedProperties(project);

        String explicit = configValue(execution, "outputDirectory");
        if (explicit != null) {
            return absolute(base, interpolate(explicit, project, props));
        }

        if ("org.xolstice.maven.plugins".equals(groupId) && "protobuf-maven-plugin".equals(artifactId)) {
            if ("compile".equals(goal)) {
                String p = props.getProperty("javaOutputDirectory");
                return absolute(base, p != null ? interpolate(p, project, props)
                        : buildDir + "/generated-sources/protobuf/java");
            }
            if ("compile-custom".equals(goal)) {
                String p = props.getProperty("protocPluginOutputDirectory");
                if (p != null) {
                    return absolute(base, interpolate(p, project, props));
                }
                String pluginId = configValue(execution, "pluginId");
                if (pluginId == null) {
                    pluginId = props.getProperty("protocPluginId");
                }
                if (pluginId == null) {
                    return null; // misconfigured execution, plugin itself would fail too
                }
                return absolute(base, buildDir + "/generated-sources/protobuf/" + interpolate(pluginId, project, props));
            }
            String lang = goal.startsWith("compile-") ? goal.substring("compile-".length()) : null;
            if (lang != null) {
                String p = props.getProperty(lang + "OutputDirectory");
                return absolute(base, p != null ? interpolate(p, project, props)
                        : buildDir + "/generated-sources/protobuf/" + lang);
            }
            return null;
        }

        if ("io.github.ascopes".equals(groupId) && "protobuf-maven-plugin".equals(artifactId)) {
            String p = props.getProperty("protobuf.compiler.outputDirectory");
            return absolute(base, p != null ? interpolate(p, project, props)
                    : buildDir + "/generated-sources/protobuf");
        }
        return null;
    }

    private static Properties mergedProperties(MavenProject project) {
        Properties p = new Properties();
        p.putAll(project.getProperties());
        p.putAll(System.getProperties());
        return p;
    }

    private static String configValue(MojoExecution execution, String name) {
        Xpp3Dom cfg = execution.getConfiguration();
        if (cfg == null) {
            return null;
        }
        Xpp3Dom child = cfg.getChild(name);
        if (child == null) {
            return null;
        }
        String v = child.getValue();
        if (v == null || v.isBlank()) {
            return null;
        }
        // "${javaOutputDirectory}" with no such property means "use default"
        if (v.trim().matches("\\$\\{[^}]+}") ) {
            String key = v.trim().substring(2, v.trim().length() - 1);
            if (!key.startsWith("project.") && !key.equals("basedir")) {
                return null;
            }
        }
        return v.trim();
    }

    private static String interpolate(String v, MavenProject project, Properties props) {
        String out = v
                .replace("${project.build.directory}", project.getBuild().getDirectory())
                .replace("${project.build.outputDirectory}", project.getBuild().getOutputDirectory())
                .replace("${project.basedir}", project.getBasedir().getAbsolutePath())
                .replace("${basedir}", project.getBasedir().getAbsolutePath());
        for (int i = 0; i < 5 && out.contains("${"); i++) {
            int s = out.indexOf("${");
            int e = out.indexOf('}', s);
            if (e < 0) {
                break;
            }
            String val = props.getProperty(out.substring(s + 2, e));
            if (val == null) {
                break;
            }
            out = out.substring(0, s) + val + out.substring(e + 1);
        }
        return out;
    }

    private static File absolute(File base, String path) {
        File f = new File(path);
        return f.isAbsolute() ? f : new File(base, path);
    }

    private static void log(String msg, Throwable t) {
        try {
            ILog.of(Platform.getBundle(BUNDLE_ID)).log(Status.warning(msg, t));
        } catch (Throwable ignore) {
            // logging must never break project import
        }
    }
}
